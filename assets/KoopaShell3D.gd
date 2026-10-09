@icon("res://assets/koopa_shell3d.svg")
class_name KoopaShell3D
extends MeshInstance3D

## Scripted mesh movement with LibSM64 group surfaces; no Godot collision bodies.
## LibSM64 handles riding movement/actions once Mario enters the shell action.
##
## Give the shell a visual by either:
##   1. Instantiating its scene with the shell model child, or
##   2. Letting Koopa3D spawn it via its shell_scene export.
## A bare KoopaShell3D.new() has no visible mesh or LibSM64 collision.

signal picked_up(mario: LibSM64Mario)
signal thrown(mario: LibSM64Mario)
signal landed

enum State {
	IDLE,
	HELD,
	THROWN,
	BOUNCING,
	STATIONARY
}

const MAX_STEP := 0.5
const LevelGlobalsScript = preload("res://libsm64_godot_demo/shared/globals/level_globals.gd")
const RIDING_SHELL_GROUND_ACTION: int = 0x20810446
const RIDING_SHELL_JUMP_ACTION: int = 0x0281089A
const RIDING_SHELL_FALL_ACTION: int = 0x0081089B
const RIDING_SHELL_WALL_BONK_ACTIONS: Array[int] = [
	LibSM64.ACT_BACKWARD_GROUND_KB,
	LibSM64.ACT_SOFT_BONK,
	LibSM64.ACT_AIR_HIT_WALL,
	LibSM64.ACT_BACKWARD_AIR_KB,
	LibSM64.ACT_FORWARD_AIR_KB,
	LibSM64.ACT_HARD_FORWARD_AIR_KB,
	LibSM64.ACT_HARD_BACKWARD_AIR_KB
]
const RIDING_SHELL_ANIMATION: LibSM64.MarioAnimID = LibSM64.MarioAnimID.MARIO_ANIM_RIDING_SHELL
const RIDING_SHELL_JUMP_ANIMATION: LibSM64.MarioAnimID = LibSM64.MarioAnimID.MARIO_ANIM_JUMP_RIDING_SHELL
const START_RIDING_SHELL_ANIMATION: LibSM64.MarioAnimID = LibSM64.MarioAnimID.MARIO_ANIM_START_RIDING_SHELL

@export_group("Interpolation")
@export var interpolate: bool = true

@export_group("Physics")
@export var gravity := 20.0
@export var throw_force := 15.0
@export var throw_arc := 8.0
@export var bounce_factor := 0.7
@export var friction := 8.0
@export var stop_speed := 1.0
@export var max_bounces := 3
@export var lifetime := 10.0
@export var stationary_at_spawn: bool = false
@export var despawn_when_stopped := true

@export_group("Ray Physics")
@export var floor_mask := 1
@export var wall_mask := 1
@export var shell_radius := 0.5
@export var wall_ray_height := 0.3
@export var floor_ray_up := 0.5
@export var floor_snap := 0.2
@export var max_fall_speed := 30.0
@export var despawn_below_y := -100.0

@export_group("Riding")
## Offset from Mario's feet-origin to the shell root, in Mario-local coordinates.
## The shell surface trigger is about 0.439 units above the shell root.
@export var riding_offset: Vector3 = Vector3(0.0, -0.43875632, 0.0)

@export_group("Pickup")
@export var pickup_radius := 1.5
@export var hold_distance := 1.2
@export var hold_height := 1.0

@export_group("References")
@export var shell_mesh: Node3D

var state := State.IDLE
var velocity := Vector3.ZERO
var bounce_count := 0
var spawn_inherited_velocity: Vector3 = Vector3.ZERO
var life_timer := 0.0
var spin_speed := 0.0

var _mario: LibSM64Mario = null
var _grounded := false
var _moving_shell: bool = false

## Vertical speed at the moment of the last floor contact (negative).
## _integrate() zeroes velocity.y on landing, so this is how the throw
## bounce reads the impact speed on the following frame.
var _impact_speed := 0.0
var _surface_nodes: Array[MeshInstance3D] = []
var _surface_handler: LibSM64SurfaceObjectsHandler = null
var _shell_riding: bool = false
var _shell_riding_music_played: bool = false
var _shell_was_z_pressed: bool = false
var _shell_consumed: bool = false
var _shell_world_surfaces_disabled: bool = false
var _surfaces_registered: bool = false


func _apply_interpolation_setting() -> void:
	# Mario already interpolates his pose in _process(). Do not interpolate
	# the riding shell a second time on Godot's physics timeline.
	PhysicsInterpolationSetting.apply_to(self, interpolate and not _shell_riding)


func _ready() -> void:
	add_to_group("koopa_shells")
	floor_mask |= LibSM64SurfaceHandlerBase.OBJECT_COLLISION_LAYER
	wall_mask |= LibSM64SurfaceHandlerBase.OBJECT_COLLISION_LAYER
	_apply_interpolation_setting()
	reset_physics_interpolation()
	if shell_mesh == null:
		shell_mesh = _find_mesh_instance(self)
	if shell_mesh == null:
		push_warning("KoopaShell3D: no shell mesh assigned.")
	else:
		shell_mesh.rotation_order = EULER_ORDER_YXZ
	# These shell meshes are registered as LibSM64 surface objects here.
	_moving_shell = true
	if stationary_at_spawn:
		state = State.IDLE
		velocity = Vector3.ZERO
	else:
		velocity = spawn_inherited_velocity
		state = State.THROWN if velocity.y > 0.0 else (State.BOUNCING if velocity.length_squared() > 0.0 else State.IDLE)
	_try_find_mario()
	_register_libsm64_surfaces()


func _process(_delta: float) -> void:
	if _shell_riding and not _shell_consumed:
		_sync_riding_transform()


func _sync_riding_transform() -> void:
	if not is_instance_valid(_mario):
		return
	# Follow the same interpolated pose that Mario published for this frame.
	var facing := Basis(Vector3.UP, _mario.face_angle)
	global_transform = Transform3D(facing, _mario.global_position + facing * riding_offset)


func _physics_process(delta: float) -> void:
	_apply_interpolation_setting()
	_register_libsm64_surfaces()
	_try_find_mario()
	_update_riding_state()
	if _shell_riding:
		return
	if _shell_consumed:
		return
	if state == State.HELD:
		queue_free()
		return

	if global_position.y < despawn_below_y:
		queue_free()
		return
	match state:
		State.IDLE:
			_act_idle(delta)
		State.HELD:
			_act_held(delta)
		State.THROWN:
			_act_thrown(delta)
		State.BOUNCING:
			_act_bouncing(delta)
		State.STATIONARY:
			_act_stationary(delta)
	_integrate(delta)
	# Move native group surfaces after pushing the mesh transform.
	if _surfaces_registered and _surface_handler != null:
		for surface_node: MeshInstance3D in _surface_nodes:
			_surface_handler.move_surface_object_now(surface_node)


func _register_libsm64_surfaces() -> void:
	if not is_inside_tree() or _surfaces_registered:
		return
	if LibSM64Global.mario_texture == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or scene_root == self:
		return
	var handler_node: Node = scene_root.find_child("LibSM64SurfaceObjectsHandler", true, false)
	if not handler_node is LibSM64SurfaceObjectsHandler:
		return
	_surface_handler = handler_node as LibSM64SurfaceObjectsHandler
	_surface_nodes.clear()
	var all_surfaces_found: bool = true
	for surface_name: String in ["Collider_inc_c", "Riding_trigger_inc_c"]:
		var surface_node: Node = find_child(surface_name, true, false)
		if surface_node is MeshInstance3D:
			var mesh_node: MeshInstance3D = surface_node as MeshInstance3D
			_surface_nodes.append(mesh_node)
			if _surface_handler.get_surface_object_id(mesh_node) < 0:
				_surface_handler.load_surface_object(mesh_node)
		else:
			all_surfaces_found = false
			push_warning("KoopaShell3D: missing mesh surface %s." % surface_name)
	_surfaces_registered = all_surfaces_found


func _update_riding_state() -> void:
	if _mario == null or _shell_consumed:
		return
	var mario_action: int = int(_mario.action)
	var riding_now: bool = mario_action == RIDING_SHELL_GROUND_ACTION or mario_action == RIDING_SHELL_JUMP_ACTION or mario_action == RIDING_SHELL_FALL_ACTION
	if not _shell_riding:
		# Mario's riding action is shared state, not ownership of every shell.
		for other in get_tree().get_nodes_in_group("koopa_shells"):
			if other != self and other._shell_riding:
				return
		if riding_now and not _can_start_shell_ride():
			return
	if _shell_riding:
		var z_pressed: bool = Input.is_action_pressed(_mario.mario_inputs_button_z)
		var wall_bonked: bool = RIDING_SHELL_WALL_BONK_ACTIONS.has(mario_action)
		if wall_bonked or (z_pressed and not _shell_was_z_pressed):
			_consume_ridden_shell()
			return
		_shell_was_z_pressed = z_pressed
	if not riding_now and _can_start_shell_ride():
		_mario.action = RIDING_SHELL_GROUND_ACTION as LibSM64.ActionFlags
		mario_action = int(_mario.action)
		riding_now = mario_action == RIDING_SHELL_GROUND_ACTION
	if riding_now and not _shell_riding:
		_shell_riding = true
		# Lower priorities run first, regardless of where a spawned shell lives
		# in the scene tree. Mario must finish interpolating before we follow.
		process_priority = _mario.process_priority + 1
		_apply_interpolation_setting()
		reset_physics_interpolation()
		_shell_was_z_pressed = Input.is_action_pressed(_mario.mario_inputs_button_z)
		picked_up.emit(_mario)
		state = State.HELD
		_set_shell_world_collision_enabled(false)
		_mario.anim_id = START_RIDING_SHELL_ANIMATION
		_mario.anim_frame = 0
		var level_globals_node: Node = get_tree().get_first_node_in_group("level_globals")
		if level_globals_node == null:
			var scene_root: Node = get_tree().current_scene
			if scene_root != null:
				level_globals_node = scene_root.find_child("LevelGlobals", true, false)
		if level_globals_node is LevelGlobals:
			(level_globals_node as LevelGlobals).play_shell_riding_music()
	elif not riding_now and _shell_riding:
		_consume_ridden_shell()
		return

	if riding_now and _shell_riding:
		_mario.collision_position_offset = -riding_offset
		_sync_riding_transform()
		_update_shell_riding_animation(mario_action)


func _consume_ridden_shell() -> void:
	if _shell_consumed:
		return
	_shell_consumed = true
	_shell_riding = false
	if _mario != null:
		_mario.collision_position_offset = Vector3.ZERO
		if int(_mario.action) == RIDING_SHELL_GROUND_ACTION:
			_mario.action = LibSM64.ACT_IDLE
	_set_shell_world_collision_enabled(false)
	visible = false
	_stop_shell_riding_music()
	queue_free()


func _set_shell_world_collision_enabled(enabled: bool) -> void:
	if _surface_handler == null or not _surfaces_registered:
		return
	if enabled == (not _shell_world_surfaces_disabled):
		return
	for surface_node: MeshInstance3D in _surface_nodes:
		# Both LibSM64 shell meshes become intangible while riding.
		if enabled:
			if _surface_handler.get_surface_object_id(surface_node) < 0:
				_surface_handler.load_surface_object(surface_node)
		else:
			_surface_handler.unload_surface_object(surface_node)
	_shell_world_surfaces_disabled = not enabled


func _update_shell_riding_animation(mario_action: int) -> void:
	if mario_action == RIDING_SHELL_GROUND_ACTION:
		if _mario.anim_id != RIDING_SHELL_ANIMATION:
			_mario.anim_id = RIDING_SHELL_ANIMATION
	elif mario_action == RIDING_SHELL_JUMP_ACTION or mario_action == RIDING_SHELL_FALL_ACTION:
		if _mario.anim_id != RIDING_SHELL_JUMP_ANIMATION:
			_mario.anim_id = RIDING_SHELL_JUMP_ANIMATION
	else:
		if _mario.anim_id != RIDING_SHELL_ANIMATION:
			_mario.anim_id = RIDING_SHELL_ANIMATION


func _stop_shell_riding_music() -> void:
	var level_globals_node: Node = get_tree().get_first_node_in_group("level_globals")
	if level_globals_node == null:
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			level_globals_node = scene_root.find_child("LevelGlobals", true, false)
	if level_globals_node is LevelGlobals:
		(level_globals_node as LevelGlobals).stop_shell_riding_music()
		return
	push_warning("KoopaShell3D: no usable LevelGlobals found; shell music could not be stopped.")


func _can_start_shell_ride() -> bool:
	if not is_available_for_koopa() or _mario == null:
		return false
	# A Koopa stomp bounces Mario upward. Do not cancel that bounce by treating
	# his feet, still near the newly spawned shell, as another landing.
	if _mario.velocity.y > 0.0:
		return false
	if not _surfaces_registered:
		return false
	var offset: Vector3 = _mario.global_position - global_position
	var horizontal_distance: float = Vector2(offset.x, offset.z).length()
	var shell_top: float = global_position.y + 0.43875632
	var standing_on_shell: bool = horizontal_distance <= shell_radius and absf(_mario.global_position.y - shell_top) <= 0.65
	var landing_on_shell: bool = horizontal_distance <= shell_radius and offset.y >= 0.7 and offset.y <= 1.8 and _mario.velocity.y < 0.0
	return standing_on_shell or landing_on_shell


func is_available_for_koopa() -> bool:
	return not _shell_consumed and not _shell_riding and state != State.HELD and not is_queued_for_deletion()


func try_reclaim() -> bool:
	if not is_available_for_koopa():
		return false
	# koopa_unshelled_act_dive: Mario gets priority within 200 N64 units.
	if is_instance_valid(_mario) and _mario.global_position.distance_to(global_position) <= 200.0 / LibSM64.scale_factor:
		return false
	_shell_consumed = true
	_set_shell_world_collision_enabled(false)
	visible = false
	queue_free()
	return true


func _exit_tree() -> void:
	if _shell_riding and is_instance_valid(_mario):
		_mario.collision_position_offset = Vector3.ZERO
		_stop_shell_riding_music()
	if is_instance_valid(_surface_handler):
		for surface in _surface_nodes:
			if is_instance_valid(surface):
				_surface_handler.unload_surface_object(surface)


func _push_mario_from_shell() -> void:
	return


func _act_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _act_held(_delta: float) -> void:
	queue_free()


func _act_thrown(delta: float) -> void:
	# Spin while flying
	if shell_mesh:
		shell_mesh.rotation.y += 15.0 * delta

	# Check for landing. _integrate() zeroes velocity.y when it snaps to
	# the floor, so bounce using the stored impact speed instead.
	if _grounded and velocity.y <= 0.0:
		velocity.y = -_impact_speed * bounce_factor
		_impact_speed = 0.0
		bounce_count += 1

		if bounce_count >= max_bounces or velocity.y < 2.0:
			velocity.y = 0.0
			state = State.BOUNCING
			landed.emit()


func _act_bouncing(delta: float) -> void:
	if not _grounded:
		return
	# Apply friction
	var horiz := Vector2(velocity.x, velocity.z)
	var speed := move_toward(horiz.length(), 0.0, friction * delta)

	if speed < 0.01:
		horiz = Vector2.ZERO
	else:
		horiz = horiz.normalized() * speed

	velocity.x = horiz.x
	velocity.z = horiz.y

	# Spin based on speed
	if shell_mesh:
		spin_speed = PI if speed <= stop_speed else speed * 3.0
		shell_mesh.rotation.y += spin_speed * delta

	if speed <= stop_speed:
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.STATIONARY
		life_timer = lifetime


func _act_stationary(delta: float) -> void:
	if shell_mesh:
		shell_mesh.rotation_degrees.y += 180.0 * delta
	if not despawn_when_stopped:
		return
	life_timer -= delta

	# Blink during the last moments. Node3D has no modulate property, so
	# visibility toggling is used instead.
	if shell_mesh:
		if life_timer < 2.0:
			shell_mesh.visible = (
				fmod(maxf(life_timer, 0.0), 0.3) > 0.15
			)
		else:
			shell_mesh.visible = true


	if life_timer <= 0.0:
		queue_free()


# --- Raycast Physics (same pattern as Koopa3D) ---

func _integrate(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	# Match bhv_koopa_shell_loop: standard object gravity while moving.
	if _moving_shell:
		velocity.y -= gravity * delta
		velocity.y = maxf(velocity.y, -max_fall_speed)
	else:
		velocity.y = 0.0

	# Horizontal movement + wall rays
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horiz.length()

	if speed > 0.01:
		var total := speed * delta
		var steps := maxi(1, ceili(total / MAX_STEP))
		var sub := total / float(steps)

		for i in steps:
			# Recompute from current velocity each step so a wall bounce
			# in an earlier step changes the direction of later steps.
			var cur := Vector3(velocity.x, 0.0, velocity.z)
			var cur_speed := cur.length()

			if cur_speed < 0.01:
				break

			var dir := cur / cur_speed

			var from := global_position + Vector3.UP * wall_ray_height
			var query := PhysicsRayQueryParameters3D.create(
				from,
				from + dir * (shell_radius + sub)
			)
			query.collision_mask = wall_mask

			var hit := space.intersect_ray(query)

			if hit:
				var normal: Vector3 = hit.normal

				# Bounce off walls
				var bounced := velocity.bounce(normal)
				velocity.x = bounced.x * bounce_factor
				velocity.z = bounced.z * bounce_factor

				# Move to wall contact point
				var hit_pos: Vector3 = hit.position
				var dist := (
					from.distance_to(hit_pos) - shell_radius
				)
				global_position += dir * maxf(dist, 0.0)

				continue

			global_position += dir * sub

	# Vertical movement + floor snap
	var drop := velocity.y * delta

	if velocity.y <= 0.0:
		var from := global_position + Vector3.UP * floor_ray_up
		var reach := floor_ray_up + maxf(floor_snap, -drop + 0.05)

		var query := PhysicsRayQueryParameters3D.create(
			from,
			from + Vector3.DOWN * reach
		)
		query.collision_mask = floor_mask

		var floor_hit := space.intersect_ray(query)

		if floor_hit:
			# Remember the impact speed before zeroing it - the throw
			# bounce needs it on the next frame.
			_impact_speed = velocity.y
			global_position.y = (floor_hit.position as Vector3).y
			velocity.y = 0.0
			_grounded = true
		else:
			global_position.y += drop
			_grounded = false
	else:
		global_position.y += drop
		_grounded = false


# --- Actions ---

func _check_pickup() -> void:
	return


func attach_to_mario(_mario_node: LibSM64Mario) -> void:
	return


func _pickup() -> void:
	return


func _throw() -> void:
	return


func _drop() -> void:
	state = State.IDLE
	velocity = Vector3.ZERO


# --- Helpers ---

func _find_mesh_instance(root: Node) -> Node3D:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			return child as Node3D
		var nested: Node3D = _find_mesh_instance(child)
		if nested != null:
			return nested
	return null


func _try_find_mario() -> void:
	if is_instance_valid(_mario):
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var mario_node: Node = scene_root.get_node_or_null("LibSM64Mario")
	if mario_node is LibSM64Mario:
		_mario = mario_node as LibSM64Mario

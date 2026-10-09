@icon("res://assets/koopa3d.svg")
class_name Koopa3D
extends CharacterBody3D

## Koopa state machine, ported from SM64's koopa.inc.c and shared object helpers.
## Speeds below are N64 units/frame (30 Hz); positions and hitboxes are Godot units.
## Rendering yaw never feeds back into the movement heading.

signal shell_popped
signal squished
signal race_finished
signal race_requested(dialog_id: int)
signal race_started
signal race_result(dialog_id: int)
signal race_star_requested(world_position: Vector3)

enum State {
	IDLE, WALK_START, WALK, WALK_STOP, FLEE, SLIDE, GET_UP,
	UNSHELLED_RUN, DIVE, KNOCKBACK, SQUISHED,
	RACE_WAIT, RACE_COUNTDOWN, RACE, RACE_DECELERATE, RACE_STOP, RACE_DONE,
}

const FPS := 30.0
const WORLD_MASK: int = 1 | LibSM64SurfaceHandlerBase.OBJECT_COLLISION_LAYER
const BOB_KOOPA_PATH := [
	Vector3(-2220, 204, 5520),
	Vector3(-2020, 204, 5820),
	Vector3(760, 765, 5680),
	Vector3(1920, 768, 5040),
	Vector3(2000, 768, 4360),
	Vector3(1240, 768, 3600),
	Vector3(-280, 768, 2720),
	Vector3(-1680, 768, 1840),
	Vector3(-2280, 0, 1800),
	Vector3(-2720, 0, 1120),
	Vector3(-2520, 0, 480),
	Vector3(-1720, 0, 120),
	Vector3(560, 630, -840),
	Vector3(2700, 1571, -1500),
	Vector3(4520, 1830, -2600),
	Vector3(6240, 1943, -3500),
	Vector3(6380, 2066, -6180),
	Vector3(4000, 2390, -7720),
	Vector3(-120, 2608, -5515),
	Vector3(-180, 2641, -4860),
	Vector3(580, 2769, -3380),
	Vector3(1670, 2867, -2580),
	Vector3(2216, 2900, -2126),
	Vector3(3167, 2965, -1870),
	Vector3(4069, 3050, -2487),
	Vector3(4880, 3037, -3416),
	Vector3(5020, 3181, -5760),
	Vector3(4660, 3354, -6300),
	Vector3(3940, 3514, -6800),
	Vector3(3200, 3619, -6850),
	Vector3(1290, 3768, -5793),
	Vector3(1150, 3900, -3670),
	Vector3(2980, 4046, -2930),
	Vector3(4334, 4186, -3680),
	Vector3(4180, 4242, -4220),
	Vector3(3660, 4242, -4380),
]


const THI_KOOPA_PATH := [
	Vector3(-1900, -511, 2400),
	Vector3(-2750, -511, 3300),
	Vector3(-4900, -511, 1200),
	Vector3(-4894, 100, -2146),
	Vector3(-5200, 143, -5050),
	Vector3(-2800, -962, -4900),
	Vector3(500, -1637, -4900),
	Vector3(1500, -2047, -5200),
	Vector3(2971, -2046, -5428),
	Vector3(5642, -1535, -5442),
	Vector3(6371, -1535, -6271),
	Vector3(6814, -1535, -6328),
]

@export_group("Koopa")
@export var is_shelled := true
@export var tiny := false
@export var interpolate := true
@export var model_yaw_offset := 0.0
@export var walk_speed := 3.0
@export var shelled_flee_speed := 17.0
@export var run_speed := 20.0
@export var flee_trigger_distance := 3.0
@export var flee_give_up_distance := 8.0
@export var home_radius := 10.0
@export var koopa_radius := 0.5
@export var koopa_top_height := 0.6
@export_flags_3d_physics var world_mask: int = WORLD_MASK
@export var despawn_below_y := -100.0
@export var shell_scene: PackedScene = preload("res://assets/koopa_shell_popped.tscn")
@export var coin_scene: PackedScene = preload("res://assets/coin.tscn")
## Initial shell velocity in Godot units/second, with a random horizontal heading.
@export var shell_pop_force := 6.0
@export var shell_pop_up_speed := 3.0

@export_group("Koopa the Quick")
## Race mode waits for start_race(); it never starts from _ready().
@export var race_mode := false
@export_enum("Bob-omb Battlefield", "Tiny-Huge Island") var race_index := 0
## Optional custom path in Godot WORLD coordinates. Empty selects the decomp path.
@export var race_path := PackedVector3Array()
@export var race_endpoint: Node3D

var state: State = State.IDLE
var _mario: LibSM64Mario
var _home := Vector3.ZERO
var _move_yaw := 0.0
var _target_yaw := 0.0
var _forward_speed := 0.0
var _vertical_speed := 0.0
var _state_frames := 0.0
var _countdown := 0.0
var _turning := false
var _turn_countdown := 0.0
var _intangible_frames := 0.0
var _mario_contact_cooldown := 0.0
var _grounded := false
var _hit_wall := false
var _hit_edge := false
var _wall_normal := Vector3.ZERO
var _agility := 1.0
var _shell_target: KoopaShell3D
var _players: Array[AnimationPlayer] = []
var _animation := ""
var _animation_frames := 30.0
var _footstep_frames := 0.0
var _waypoint := 1
var _race_jump := false
var _race_landing := false
var _race_running := false
var _race_status := 0
var _race_ended := false
var _race_cheated := false
var _race_prompted := false
var _race_reported := false


func _ready() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)
	collision_layer = 0
	collision_mask = world_mask
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(78.0)
	# Keep collision in world units even when the imported visual scene is scaled.
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = koopa_radius
	shape.height = koopa_top_height
	collider.shape = shape
	add_child(collider)
	collider.scale = Vector3.ONE / global_basis.get_scale().abs()
	collider.position.y = koopa_top_height * 0.5 / global_basis.get_scale().y
	_move_yaw = global_rotation.y - model_yaw_offset
	_target_yaw = _move_yaw
	_agility = 1.6 / 3.0 if tiny else 1.0
	for path in ["Shelled/ShelledPlayer", "Shelless/ShellessPlayer", "Shellless/ShelllessPlayer"]:
		var player := get_node_or_null(path) as AnimationPlayer
		if player != null:
			_players.append(player)
	_apply_shell_state()
	_home = global_position
	_enter(State.RACE_WAIT if race_mode else (State.IDLE if is_shelled else State.UNSHELLED_RUN))
	if race_path.is_empty():
		for point: Vector3 in (BOB_KOOPA_PATH if race_index == 0 else THI_KOOPA_PATH):
			race_path.append(sm64_to_world(point))
	# Wait for level surfaces to be installed before DROP_TO_FLOOR / SET_HOME.
	_drop_to_floor.call_deferred()


static func sm64_to_world(point: Vector3) -> Vector3:
	# Same mapping as bob_omb_battlefield_surfaces.convert_sm64_to_godot.
	return Vector3(-point.z, point.y, point.x) / LibSM64.scale_factor


func _drop_to_floor() -> void:
	var hit := _ray(global_position + Vector3.UP, global_position + Vector3.DOWN * 200.0)
	if not hit.is_empty():
		global_position.y = hit.position.y
		_grounded = true
	_home = global_position
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if state == State.SQUISHED:
		return
	if global_position.y < despawn_below_y:
		queue_free()
		return
	_find_mario()
	var frames := delta * FPS
	_state_frames += frames
	_intangible_frames = maxf(0.0, _intangible_frames - frames)
	_mario_contact_cooldown = maxf(0.0, _mario_contact_cooldown - frames)
	_check_mario_interaction()
	if state == State.SQUISHED:
		return
	if race_mode:
		_update_race(frames)
	elif state == State.KNOCKBACK:
		if (_grounded and _state_frames > 10.0) or _hit_wall:
			_squish_die()
	elif is_shelled:
		_update_shelled(frames)
	else:
		_update_unshelled(frames)
	if state == State.SQUISHED:
		return
	_move(delta)
	if not is_shelled and state in [State.DIVE, State.SLIDE]:
		_try_reclaim_shell()
	global_rotation.y = rotate_toward(global_rotation.y, _move_yaw + model_yaw_offset, TAU * 0x600 / 65536.0 * frames)
	_footsteps(frames)


func _enter(next: State) -> void:
	state = next
	_state_frames = 0.0
	match state:
		State.IDLE, State.RACE_WAIT, State.RACE_DONE:
			_forward_speed = 0.0
			_animate("7 - Stopped", false)
		State.WALK_START:
			_animate("11 - Walk Start", false)
		State.WALK:
			_countdown = SM64RNG.random_linear_offset(30, 100)
			_animate("9 - Walk")
		State.WALK_STOP, State.RACE_STOP:
			_animate("10 - Walk Stop", false)
		State.FLEE:
			_animate("1 - Run Away")
		State.UNSHELLED_RUN:
			_animate("3 - Running")
		State.SLIDE:
			_animate("5 - Laying (Shelled)" if is_shelled else "2 - Laying (Unshelled)", false)
		State.DIVE:
			_countdown = 20.0
			_animate("5 - Laying (Shelled)", false)
		State.GET_UP:
			_animate("6 - Stand Up", false)
		State.RACE_COUNTDOWN:
			_forward_speed = 0.0
			_animate("7 - Stopped")
		State.RACE:
			_animate("11 - Walk Start", false)
		State.RACE_DECELERATE:
			_animate("9 - Walk")
		State.KNOCKBACK:
			_animate("2 - Laying (Unshelled)", false)


func _update_shelled(frames: float) -> void:
	match state:
		State.IDLE:
			_forward_speed = 0.0
			if _state_frames >= _animation_frames:
				_target_yaw = _move_yaw + (PI / 4.0) * SM64RNG.random_sign()
				_enter(State.WALK_START)
		State.WALK_START, State.WALK, State.WALK_STOP:
			_wander_turn(0x200, frames)
			if state == State.WALK_START:
				_approach_speed(walk_speed * _agility, 0.3 * _agility, frames)
				if _state_frames >= _animation_frames:
					_enter(State.WALK)
			elif state == State.WALK:
				_countdown -= frames
				if _countdown <= 0.0:
					_enter(State.WALK_STOP)
			else:
				_approach_speed(0.0, _agility, frames)
				if _state_frames >= _animation_frames:
					_enter(State.IDLE)
		State.FLEE:
			var far_home := global_position.distance_to(_home) > home_radius
			if not far_home and _state_frames > 30.0 and _distance_to_mario() > flee_give_up_distance:
				_approach_speed(0.0, 1.0, frames)
				if is_zero_approx(_forward_speed):
					_enter(State.IDLE)
			else:
				_target_yaw = _yaw_to(_home) if far_home else _yaw_to_mario() + PI
				_avoid_and_turn(0x400, frames)
				_approach_speed(shelled_flee_speed, 1.0, frames)
		State.SLIDE:
			_slide(frames, 0.3)
		State.GET_UP:
			if _state_frames >= _animation_frames:
				_enter(State.IDLE)
	if state in [State.IDLE, State.WALK_START, State.WALK, State.WALK_STOP]:
		if flee_trigger_distance > 0.0 and _distance_to_mario() < flee_trigger_distance:
			if absf(angle_difference(_move_yaw, _yaw_to_mario())) < 3.0 * PI / 8.0:
				_enter(State.FLEE)


func _update_unshelled(frames: float) -> void:
	match state:
		State.UNSHELLED_RUN:
			_shell_target = _nearest_shell()
			if is_instance_valid(_shell_target):
				_target_yaw = _yaw_to(_shell_target.global_position)
			elif global_position.distance_to(_home) > home_radius:
				_target_yaw = _yaw_to(_home)
			else:
				_turn_countdown -= frames
				if _turn_countdown <= 0.0:
					_target_yaw = _move_yaw + (PI / 4.0) * SM64RNG.random_sign()
					_turn_countdown = SM64RNG.random_linear_offset(30, 30)
			var shell_yaw := _target_yaw
			if _distance_to_mario() <= flee_give_up_distance:
				if not is_instance_valid(_shell_target) or absf(angle_difference(shell_yaw, _yaw_to_mario() + PI)) >= PI / 4.0:
					_target_yaw = _yaw_to_mario() + PI
			_avoid_and_turn(0x600, frames)
			_approach_speed(run_speed, 1.0, frames)
			if is_instance_valid(_shell_target) and not _turning:
				var distance := global_position.distance_to(_shell_target.global_position) * LibSM64.scale_factor
				if is_equal_approx(_forward_speed, run_speed) and distance < 600.0 and absf(angle_difference(_move_yaw, shell_yaw)) < TAU * 0xC00 / 65536.0:
					_move_yaw = shell_yaw
					_forward_speed *= 1.2
					_vertical_speed = distance / 20.0
					_enter(State.DIVE)
		State.SLIDE, State.DIVE:
			_try_reclaim_shell()
			_slide(frames, 0.5)
		State.GET_UP:
			if _state_frames >= _animation_frames:
				_enter(State.UNSHELLED_RUN)


func _slide(frames: float, deceleration: float) -> void:
	if _hit_wall:
		var reflected := _direction().bounce(_wall_normal)
		_move_yaw = atan2(reflected.x, reflected.z)
	if _grounded:
		_approach_speed(0.0, deceleration, frames)
	if is_zero_approx(_forward_speed) and _grounded:
		_countdown = maxf(0.0, _countdown - frames)
		if _countdown <= 0.0:
			_enter(State.GET_UP)


func _wander_turn(turn_units: int, frames: float) -> void:
	if global_position.distance_to(_home) > home_radius and not _turning:
		_target_yaw = _yaw_to(_home)
	_avoid_and_turn(turn_units, frames)


func _avoid_and_turn(turn_units: int, frames: float) -> void:
	# Preserve an avoidance heading until the turn completes. Target seeking must
	# not overwrite a wall reflection on the next frame.
	if not _turning and (_hit_wall or _hit_edge):
		var reflected := _direction().bounce(_wall_normal) if _hit_wall else -_direction()
		_avoid_yaw = atan2(reflected.x, reflected.z)
		_turning = true
	var target := _avoid_yaw if _turning else _target_yaw
	_move_yaw = rotate_toward(_move_yaw, target, TAU * turn_units / 65536.0 * frames)
	if absf(angle_difference(_move_yaw, target)) < 0.01:
		_turning = false


var _avoid_yaw := 0.0


func _move(delta: float) -> void:
	var units_per_second := FPS / LibSM64.scale_factor
	var direction := _direction()
	var motion := direction * _forward_speed * units_per_second
	_hit_edge = _grounded and not _floor_ahead(direction, maxf(koopa_radius + 0.1, motion.length() * delta + koopa_radius))
	# Like cur_obj_move_standard, reject a grounded step over an edge. KtQ uses
	# the flag next tick to jump; airborne dives remain ballistic.
	if _hit_edge and _vertical_speed <= 0.0:
		motion = Vector3.ZERO
	var gravity_per_frame := 6.0 if _race_jump else (6.4 / 3.0 if tiny else 4.0)
	_vertical_speed = maxf(-78.0, _vertical_speed - gravity_per_frame * delta * FPS)
	velocity = motion + Vector3.UP * _vertical_speed * units_per_second
	var previous := global_position
	move_and_slide()
	_grounded = is_on_floor()
	_hit_wall = is_on_wall()
	if _hit_wall:
		_wall_normal = get_wall_normal()
	_resolve_shell_contacts(previous)
	if _grounded and _vertical_speed < 0.0:
		_vertical_speed = 0.0
	if is_on_ceiling() and _vertical_speed > 0.0:
		_vertical_speed = 0.0
	if state in [State.DIVE, State.SLIDE] and not is_shelled:
		_try_reclaim_shell(previous)


func _floor_ahead(direction: Vector3, distance: float) -> bool:
	var from := global_position + direction * distance + Vector3.UP * 1.0
	var hit := _ray(from, from + Vector3.DOWN * 2.5)
	return not hit.is_empty() and hit.normal.y >= cos(floor_max_angle)


func _ray(from: Vector3, to: Vector3, extra: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, world_mask)
	var excluded: Array[RID] = [get_rid()]
	excluded.append_array(extra)
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query)


func _nearest_shell() -> KoopaShell3D:
	var closest: KoopaShell3D
	var best := INF
	for node in get_tree().get_nodes_in_group("koopa_shells"):
		var shell := node as KoopaShell3D
		if shell == null or not shell.is_available_for_koopa():
			continue
		var distance := global_position.distance_squared_to(shell.global_position)
		if distance < best:
			closest = shell
			best = distance
	return closest


func _resolve_shell_contacts(previous: Vector3) -> void:
	# Shells are mesh-only native surfaces, so handle Koopa contact directly.
	# A shellless dive must reach the center for the decomp reclaim check.
	if not is_shelled and state in [State.DIVE, State.SLIDE]:
		return
	for node in get_tree().get_nodes_in_group("koopa_shells"):
		var shell := node as KoopaShell3D
		if shell == null or not shell.is_available_for_koopa():
			continue
		if global_position.y > shell.global_position.y + 0.6 or global_position.y + koopa_top_height < shell.global_position.y:
			continue
		var start := Vector2(previous.x - shell.global_position.x, previous.z - shell.global_position.z)
		var step := Vector2(global_position.x - previous.x, global_position.z - previous.z)
		var radius := koopa_radius + shell.shell_radius
		var a := step.length_squared()
		var b := start.dot(step)
		var c := start.length_squared() - radius * radius
		var contact := start + step
		if c >= 0.0:
			var discriminant := b * b - a * c
			if a <= 0.000001 or b >= 0.0 or discriminant < 0.0:
				continue
			var fraction := (-b - sqrt(discriminant)) / a
			if fraction < 0.0 or fraction > 1.0:
				continue
			contact = start + step * fraction
		elif contact.length_squared() >= radius * radius:
			continue
		var normal := contact.normalized() if not contact.is_zero_approx() else Vector2.RIGHT
		global_position.x = shell.global_position.x + normal.x * (radius + 0.001)
		global_position.z = shell.global_position.z + normal.y * (radius + 0.001)
		_hit_wall = true
		_wall_normal = Vector3(normal.x, 0.0, normal.y)


func _try_reclaim_shell(previous: Vector3 = global_position) -> void:
	if is_shelled or _state_frames <= 10.0:
		return
	var shell := _nearest_shell()
	if shell == null:
		return
	var nearest := Geometry3D.get_closest_point_to_segment(shell.global_position, previous, global_position)
	if nearest.distance_to(shell.global_position) >= 50.0 / LibSM64.scale_factor:
		return
	# Distance alone must not allow a pickup through a wall or a floor.
	if not _ray(nearest + Vector3.UP * 0.25, shell.global_position + Vector3.UP * 0.25).is_empty():
		return
	if not shell.try_reclaim():
		return
	is_shelled = true
	_forward_speed *= 0.5
	_shell_target = null
	_apply_shell_state()
	_enter(State.SLIDE)


func _pop_shell(from_above := true) -> void:
	if race_mode or not is_shelled:
		return
	is_shelled = false
	_intangible_frames = 11.0
	_forward_speed = 20.0
	_vertical_speed = 0.0
	if not from_above:
		_move_yaw = _yaw_to_mario() + PI
	_countdown = 0.0
	_enter(State.SLIDE)
	if shell_scene != null:
		var shell := shell_scene.instantiate() as KoopaShell3D
		if shell != null:
			var yaw := float(SM64RNG.random_u16()) * TAU / 65536.0
			shell.stationary_at_spawn = false
			shell.despawn_when_stopped = false
			shell.spawn_inherited_velocity = Vector3(sin(yaw) * shell_pop_force, shell_pop_up_speed, cos(yaw) * shell_pop_force)
			shell.position = get_parent().to_local(global_position)
			get_parent().add_child(shell)
			_shell_target = shell
	_apply_shell_state()
	_sound(LibSM64.SOUND_OBJ_KOOPA_DAMAGE)
	shell_popped.emit()


func _check_mario_interaction() -> void:
	if not is_instance_valid(_mario) or _mario.id < 0 or _intangible_frames > 0.0 or race_mode:
		return
	var offset := _mario.global_position - global_position
	if Vector2(offset.x, offset.z).length() > koopa_radius + 0.37 or offset.y < -1.6 or offset.y > koopa_top_height + 0.35:
		return
	var action := int(_mario.action)
	var flags := int(_mario.flags)
	var descending := _mario.velocity.y < 0.0
	var stomp := (action & LibSM64.ACT_FLAG_AIR) != 0 and descending and offset.y > 0.0
	var pound := action in [LibSM64.ACT_GROUND_POUND, LibSM64.ACT_TWIRLING] and descending
	var attack := (flags & LibSM64.MARIO_METAL_CAP) != 0
	if (action & LibSM64.ACT_FLAG_ATTACKING) != 0:
		var facing := Vector3(sin(_mario.face_angle), 0.0, cos(_mario.face_angle))
		var in_front := facing.dot(-Vector3(offset.x, 0.0, offset.z).normalized()) > 0.5
		if action in [LibSM64.ACT_PUNCHING, LibSM64.ACT_MOVE_PUNCHING, LibSM64.ACT_JUMP_KICK]:
			attack = attack or (in_front and (flags & (LibSM64.MARIO_PUNCHING | LibSM64.MARIO_KICKING | LibSM64.MARIO_TRIPPING)) != 0)
		else:
			attack = attack or action in [LibSM64.ACT_SLIDE_KICK, LibSM64.ACT_SLIDE_KICK_SLIDE] or (action & LibSM64.ACT_FLAG_RIDING_SHELL) != 0 or absf(_mario.forward_velocity) >= 26.0
	if not (stomp or pound or attack):
		_knock_mario_back()
		return
	if stomp and not pound:
		_bounce_mario_off_koopa()
	if is_shelled and not tiny:
		_pop_shell(stomp or pound)
	elif stomp or pound:
		_squish_die()
	else:
		_move_yaw = _yaw_to_mario() + PI
		_forward_speed = 20.0
		_vertical_speed = 20.0
		_intangible_frames = 1000.0
		_enter(State.KNOCKBACK)


func _knock_mario_back() -> void:
	var action := int(_mario.action)
	if _mario_contact_cooldown > 0.0 or (action & (LibSM64.ACT_FLAG_INTANGIBLE | LibSM64.ACT_FLAG_INVULNERABLE)) != 0:
		return
	var away := _mario.global_position - global_position
	away.y = 0.0
	away = away.normalized() if not away.is_zero_approx() else _direction()
	var airborne := (action & LibSM64.ACT_FLAG_AIR) != 0
	# Face Koopa and recoil backwards. Set only motion/action, never damage.
	_mario.face_angle = atan2(-away.x, -away.z)
	_mario.action = LibSM64.ACT_BACKWARD_AIR_KB if airborne else LibSM64.ACT_SOFT_BACKWARD_GROUND_KB
	var speed := 16.0 / (LibSM64.scale_factor * LibSM64.tick_delta_time)
	_mario.forward_velocity = -speed
	_mario.velocity = away * speed
	_mario_contact_cooldown = 12.0


func _bounce_mario_off_koopa() -> void:
	var bounce := _mario.velocity
	# The extension's velocity setter takes world units/second, not N64
	# units/frame. 30 N64 units/frame is 9 here, not 30 (a 13m launch).
	bounce.y = 30.0 / (LibSM64.scale_factor * LibSM64.tick_delta_time)
	var feet := _mario.global_position
	feet.y = global_position.y + koopa_top_height
	_mario.teleport(feet - _mario.collision_position_offset)
	# Normalize gravity after long jumps/slide kicks, without changing XZ speed.
	# Freefall also prevents held A from extending this object bounce.
	_mario.action = LibSM64.ACT_FREEFALL
	_mario.flags = (int(_mario.flags) & ~LibSM64.MARIO_UNKNOWN_08) as LibSM64.MarioFlags
	_mario.velocity = bounce


func _squish_die() -> void:
	if state == State.SQUISHED:
		return
	_enter(State.SQUISHED)
	velocity = Vector3.ZERO
	_sound(LibSM64.SOUND_OBJ_KOOPA_FLYGUY_DEATH)
	squished.emit()
	var running_scene := get_tree().current_scene
	if coin_scene != null and running_scene != null:
		var instance := coin_scene.instantiate()
		var coin := instance as Coin3D
		if coin != null:
			coin.hitbox_size = Vector3(2.0, 2.327, 2.0)
			coin.moving_coin = true
			coin.blue_coin = true
			coin.yellow_coin = false
			coin.red_coin = false
			coin.coin_amount = 5
			# Coin3D's origin is above its sprite; keep the moving floor probe
			# above terrain on the very first frame.
			var spawn_position := global_position + Vector3.UP * (coin.coin_half_height - coin.sprite_offset_y + 0.05)
			coin.position = running_scene.to_local(spawn_position) if running_scene is Node3D else spawn_position
			running_scene.add_child(coin)
			coin.owner = running_scene
			coin.reset_physics_interpolation()
		else:
			instance.free()
			push_error("Koopa3D: coin_scene must have a Coin3D root.")
	for player in _players:
		player.pause()
	var tween := create_tween()
	tween.tween_property(self, "scale:y", scale.y * 0.15, 0.1)
	tween.tween_interval(0.4)
	tween.tween_callback(queue_free)


# Race dialogue/UI can connect these signals; normal Koopas cannot enter races.
func start_race() -> void:
	if not race_mode or state != State.RACE_WAIT or race_path.size() < 2:
		return
	_waypoint = 1
	_race_status = 0
	_race_ended = false
	_race_cheated = false
	_race_reported = false
	_race_running = false
	_race_jump = false
	_race_landing = false
	_turning = false
	_enter(State.RACE_COUNTDOWN)


func decline_race() -> void:
	if state == State.RACE_WAIT:
		_race_prompted = false
		_state_frames = -60.0


func _update_race(frames: float) -> void:
	_push_mario_from_racer()
	match state:
		State.RACE_WAIT:
			if not _race_prompted and _state_frames >= 0.0 and _distance_to_mario() < 4.0:
				_race_prompted = true
				race_requested.emit(5 if race_index == 0 else 9)
		State.RACE_COUNTDOWN:
			if _state_frames >= 50.0:
				_enter(State.RACE)
				_sound(LibSM64.SOUND_GENERAL_RACE_GUN_SHOT)
				race_started.emit()
		State.RACE:
			_update_endpoint()
			_race_step(frames)
		State.RACE_DECELERATE:
			_update_endpoint()
			_approach_speed(3.0, 1.0, frames)
			if _forward_speed <= 3.0:
				_enter(State.RACE_STOP)
		State.RACE_STOP:
			_update_endpoint()
			_approach_speed(0.0, 4.0, frames)
			if _state_frames >= _animation_frames:
				_enter(State.RACE_DONE)
				race_finished.emit()
		State.RACE_DONE:
			if not _race_reported and _distance_to_mario() < 4.0:
				_race_reported = true
				race_result.emit(6 if _race_status < 0 else ((7 if race_index == 0 else 31) if _race_status > 0 else 41))


func acknowledge_race_result() -> void:
	if state == State.RACE_DONE and _race_reported and _race_status > 0:
		_race_status = 0
		race_star_requested.emit(sm64_to_world(Vector3(3030, 4500, -4600) if race_index == 0 else Vector3(7100, -1300, -6000)))


func _update_endpoint() -> void:
	if is_instance_valid(_mario) and int(_mario.action) == LibSM64.ACT_SHOT_FROM_CANNON:
		_race_cheated = true
	if _race_ended:
		return
	var endpoint := race_endpoint.global_position if is_instance_valid(race_endpoint) else race_path[-1]
	# Endpoint gives Koopa priority if both arrive in the same tick.
	if global_position.distance_to(endpoint) < 4.0:
		_race_ended = true
	elif is_instance_valid(_mario) and _mario.global_position.distance_to(endpoint) < 4.0:
		_race_ended = true
		_race_status = -1 if _race_cheated else 1


func _race_step(frames: float) -> void:
	while _waypoint < race_path.size():
		var segment := race_path[_waypoint] - race_path[_waypoint - 1]
		var remaining := race_path[_waypoint] - global_position
		if segment.dot(remaining) > 0.0:
			break
		_waypoint += 1
	if _waypoint >= race_path.size():
		_enter(State.RACE_DECELERATE)
		return
	var target := race_path[_waypoint] - global_position
	_target_yaw = atan2(target.x, target.z)
	var agility := 4.0 if race_index == 0 else 6.0
	if _race_status != 0 and _distance_to_mario() > 15.0 and _waypoint < 29:
		agility = 8.0
	_move_yaw = rotate_toward(_move_yaw, _target_yaw, TAU * agility * 150.0 / 65536.0 * frames)
	if not _race_running:
		_approach_speed(12.0, 1.2, frames)
		if _state_frames >= _animation_frames:
			_race_running = true
			_animate("9 - Walk")
		return
	if _race_jump:
		if _grounded:
			if not _race_landing:
				_race_landing = true
				_state_frames = 0.0
				_animate("13 - Land", false)
			elif _state_frames >= _animation_frames:
				_race_jump = false
				_race_landing = false
				_animate("9 - Walk")
		return
	var downhill := 1.0 - target.y / maxf(target.length(), 0.001)
	_approach_speed(agility * 6.0 * downhill, agility * 0.1, frames)
	for player in _players:
		player.speed_scale = maxf(0.1, _forward_speed * 0.09)
	var ball_status := _detect_bowling_ball(frames)
	if _grounded and (_hit_edge or ball_status != 0):
		if ball_status < 0:
			_forward_speed = 0.0
		_vertical_speed = 80.0 if ball_status != 0 or _waypoint >= 9 else 40.0
		_race_jump = true
		_animate("12 - Jump", false)
	elif _hit_wall:
		_vertical_speed = 20.0


func _detect_bowling_ball(frames: float) -> int:
	for ball in get_tree().get_nodes_in_group("bowling_balls"):
		if not ball is Node3D or not "velocity" in ball:
			continue
		var offset: Vector3 = ball.global_position - global_position
		var ball_velocity: Vector3 = ball.velocity
		var speed := ball_velocity.dot(_direction()) * LibSM64.scale_factor / FPS
		if offset.dot(_direction()) > 0.0 and offset.length() < 4.0:
			if speed < _forward_speed * 0.7:
				return 1
			_forward_speed = maxf(0.0, _forward_speed - 2.0 * frames)
		elif offset.length() < 3.0 and speed > _forward_speed:
			return -1
	return 0


func _push_mario_from_racer() -> void:
	if not is_instance_valid(_mario) or _mario.id < 0:
		return
	var offset := _mario.global_position - global_position
	if offset.y < 0.0 or offset.y > 3.0:
		return
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	var radius := 1.8 if state == State.RACE else 1.4
	if horizontal.length() >= radius:
		return
	_knock_mario_back()


func _apply_shell_state() -> void:
	for child_name in ["Shelled", "Shelless", "Shellless"]:
		var visual := get_node_or_null(child_name) as Node3D
		if visual != null:
			visual.visible = is_shelled if child_name == "Shelled" else not is_shelled


func _animate(base: String, looped := true) -> void:
	_animation = base
	_animation_frames = 30.0
	for player in _players:
		for anim_name in player.get_animation_list():
			if String(anim_name).get_slice("|", String(anim_name).get_slice_count("|") - 1) == base:
				var animation := player.get_animation(anim_name)
				animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
				_animation_frames = maxf(1.0, animation.length * FPS)
				player.speed_scale = 1.0
				player.play(anim_name, 0.1)
				break


func _footsteps(frames: float) -> void:
	if not _grounded or state not in [State.WALK, State.FLEE, State.UNSHELLED_RUN, State.RACE]:
		return
	_footstep_frames -= frames
	if _footstep_frames <= 0.0:
		_footstep_frames = 6.0 if state == State.UNSHELLED_RUN else (11.0 if state == State.FLEE else 15.0)
		_sound(LibSM64.SOUND_OBJ_KOOPA_THE_QUICK_WALK if race_mode else LibSM64.SOUND_OBJ_KOOPA_WALK)


func _sound(sound: int) -> void:
	if not LibSM64Global.rom.is_empty():
		LibSM64.play_sound(sound, global_position)


func _approach_speed(target: float, step: float, frames: float) -> void:
	_forward_speed = move_toward(_forward_speed, target, step * frames)


func _direction() -> Vector3:
	return Vector3(sin(_move_yaw), 0.0, cos(_move_yaw))


func _yaw_to(point: Vector3) -> float:
	var offset := point - global_position
	return atan2(offset.x, offset.z)


func _yaw_to_mario() -> float:
	return _yaw_to(_mario.global_position) if is_instance_valid(_mario) else _move_yaw + PI


func _distance_to_mario() -> float:
	return global_position.distance_to(_mario.global_position) if is_instance_valid(_mario) else INF


func _find_mario() -> void:
	if is_instance_valid(_mario):
		return
	var scene := get_tree().current_scene
	if scene != null:
		_mario = scene.find_child("LibSM64Mario", true, false) as LibSM64Mario

@icon("res://assets/koopa3d.svg") # delete this line if you don't have an icon
class_name Koopa3D
extends Node3D

## GDScript port of the SM64 koopa behaviour (bhvKoopa / koopa.c).
##
## Pure raycast physics (same approach as Coin3D) - no CharacterBody3D,
## no CollisionShape3D, no physics body. The node's origin is treated as
## the koopa's FEET (the floor ray snaps global_position.y to hit.y).
##
## Shelled: wanders, runs from Mario. A stomp pops the shell -> shell-less
##          mesh, launched in a random direction with `slide_launch_force`,
##          slides on its belly, then gets up and keeps walking.
## Shell-less: another stomp squishes it, spawns a Coin3D, despawns.
##
## Animations (SM64 anim index -> action name):
##   1 -> "1 - Run Away"            (shelled flee)
##   2 -> "2 - Laying (Unshelled)"  (slide after shell pop)
##   3 -> "3 - Running"             (shellless movement)
##   5 -> "5 - Laying (Shelled)"    (unused here, kept for completeness)
##   6 -> "6 - Stand Up"
##   7 -> "7 - Stopped"             (idle)
##   9 -> "9 - Walk"                (shelled walk)
##  10 -> "10 - Walk Stop"
##  11 -> "11 - Walk Start"
##  12 -> "12 - Jump"              (race hops)
##  13 -> "13 - Land"
##   0, 4, 8 are unused in the C code and unused here.
##
## The Shelled AnimationPlayer prefixes its actions with "ArmatureObj|",
## the Shellless one doesn't - animations are resolved per-player by
## matching the name after the last '|', so both work with the same code.
##
## Expected scene layout:
##   koopa (Node3D)                   <- this script
##   ├── Shellless (Node3D)
##   │   ├── ArmatureObj
##   │   │   └── Skeleton3D
##   │   │       └── skinned
##   │   └── ShelllessPlayer
##   └── Shelled (Node3D)
##       ├── ArmatureObj
##       │   └── Skeleton3D
##       │       └── skinned
##       └── ShelledPlayer


signal shell_popped
signal squished
signal race_finished


enum State {
	IDLE,        ## koopa_shelled_act_stopped()   - anim 7
	WALK_START,  ## koopa_walk_start()            - anim 11
	WALK,        ## koopa_walk()                  - anim 9 / anim 3 when unshelled
	WALK_STOP,   ## koopa_walk_stop()             - anim 10
	FLEE,        ## koopa_shelled_act_run_from_mario() - anim 1 / anim 3
	SLIDE,       ## koopa_shelled_act_lying()     - anim 5 / anim 2
	GET_UP,      ## anim 6 -> back to wandering
	RACE,        ## follows BOB_KOOPA_PATH (Koopa the Quick, optional)
	SQUISHED,    ## shell-less koopa got stomped -> dead
}


const MAX_STEP := 0.5


## bob_seg7_trajectory_koopa (0x070116A0) - 1:1 with the C array.
## Plain const Array so it's valid on older Godot versions too.
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


@export_group("Movement")
@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var flee_speed := 17.0
@export var acceleration := 8.0
@export var turn_speed := 6.0
@export var gravity := 40.0
@export var model_yaw_offset := 0.0


@export_group("Ray Physics")
@export var floor_mask := 1
@export var wall_mask := 1
@export var koopa_radius := 0.5
@export var wall_ray_height := 0.5
@export var floor_ray_up := 1.0
@export var floor_snap := 0.3
@export var max_fall_speed := 30.0
@export var max_floor_angle_deg := 50.0
@export var edge_check_distance := 0.6
@export var edge_drop_depth := 1.5
@export var despawn_below_y := -10000.0


@export_group("Pathfinding Optimization")
## How often the edge raycast is allowed to refresh.
## Lower = more accurate, higher = cheaper.
@export var edge_check_interval := 0.10

## Force a new check after moving this far.
@export var edge_check_move_distance := 0.25

## Force a new check after turning this many radians.
@export var edge_check_turn_threshold := 0.15


@export_group("Shell Slide")
@export var slide_launch_force := 10.0
@export var slide_pop_up_speed := 2.5
@export var slide_friction := 4.0
@export var slide_stop_speed := 0.8
@export var wall_bounce_damping := 0.7


@export_group("Behaviour")
@export var idle_time := Vector2(0.6, 2.5)
@export var walk_time := Vector2(1.5, 5.0)
@export var flee_trigger_distance := 3.0
@export var flee_give_up_distance := 8.0
@export var flee_facing_cone_deg := 67.5


@export_group("Stomp")
@export var stomp_radius := 1.2
@export var koopa_top_height := 0.9
@export var mario_feet_offset := -1.0
@export var stomp_vertical_window := 1.2
@export var mario_stomp_bounce := 22.0
@export var stomp_cooldown := 0.35


@export_group("References")
@export var coin_scene: PackedScene


@export_group("Race (Koopa the Quick)")
@export var race_mode := false
@export var race_path: PackedVector3Array = BOB_KOOPA_PATH
@export var race_speed := 30.0
@export var waypoint_reach_distance := 100.0
@export var race_hop_speed := 10.0


@export_group("Animations")
@export var anim_idle: String = "7 - Stopped"
@export var anim_walk_start: String = "11 - Walk Start"
@export var anim_walk: String = "9 - Walk"
@export var anim_walk_stop: String = "10 - Walk Stop"
@export var anim_run: String = "3 - Running"
@export var anim_flee: String = "1 - Run Away"
@export var anim_lay_shelled: String = "5 - Laying (Shelled)"
@export var anim_lay_unshelled: String = "2 - Laying (Unshelled)"
@export var anim_stand_up: String = "6 - Stand Up"
@export var anim_jump: String = "12 - Jump"
@export var anim_land: String = "13 - Land"
@export var anim_speed_scale := 0.15


# --- node references ---------------------------------------------------------

@onready var _shellless_mesh: Node3D = get_node_or_null("Shelless") as Node3D
@onready var _shellless_anim: AnimationPlayer = get_node_or_null("Shelless/ShellessPlayer") as AnimationPlayer
@onready var _shelled_mesh: Node3D = get_node_or_null("Shelled") as Node3D
@onready var _shelled_anim: AnimationPlayer = get_node_or_null("Shelled/ShelledPlayer") as AnimationPlayer


# --- state -------------------------------------------------------------------

var velocity := Vector3.ZERO

var state := State.IDLE

@export var is_shelled := true

var _grounded := false
var _hit_wall := false
var _wall_normal := Vector3.FORWARD

var _mario: LibSM64Mario = null

var _target_yaw := 0.0
var _timer := 0.0
var _stomp_timer := 0.0
var _footstep_timer := 0.0

var _waypoint := 0

var _max_floor_normal_y := 0.6

var _race_air := false
var _land_timer := 0.0


# --- cached pathfinding state -----------------------------------------------

## Cached result of the "is there floor ahead?" query.
var _floor_ahead_cached := true

## Time until another floor-ahead query is allowed.
var _edge_check_timer := 0.0

## Position where the last floor-ahead query happened.
var _edge_check_position := Vector3.ZERO

## Heading used by the last floor-ahead query.
var _edge_check_yaw := 0.0


# --- animation cache ---------------------------------------------------------

var _anim_cache := {}


func _ready() -> void:
	_max_floor_normal_y = cos(deg_to_rad(max_floor_angle_deg))

	if race_path.is_empty():
		race_path = PackedVector3Array(BOB_KOOPA_PATH)

	# glTF imports come in as one-shots, so force the correct loop modes.
	for base: String in [
		anim_idle,
		anim_walk,
		anim_run,
		anim_flee,
		anim_lay_shelled,
		anim_lay_unshelled
	]:
		_set_loop(base, true)

	for base: String in [
		anim_walk_start,
		anim_walk_stop,
		anim_stand_up,
		anim_jump,
		anim_land
	]:
		_set_loop(base, false)

	_try_find_mario()
	_apply_shell_state()

	if _shellless_mesh == null or _shelled_mesh == null \
			or _shellless_anim == null or _shelled_anim == null:
		push_warning(
			"Koopa3D: expected child nodes 'Shellless' and 'Shelled', " +
			"each with an 'AnimationPlayer'."
		)

	if is_shelled:
		if _shellless_mesh:
			_shellless_mesh.hide()
		if _shelled_mesh:
			_shelled_mesh.show()
	else:
		if _shellless_mesh:
			_shellless_mesh.show()
		if _shelled_mesh:
			_shelled_mesh.hide()

	# Start with an immediate valid floor check.
	_edge_check_timer = 0.0
	_edge_check_position = global_position
	_edge_check_yaw = _target_yaw

	_enter_idle()

	if race_mode:
		start_race()


func _physics_process(delta: float) -> void:
	if state == State.SQUISHED:
		return

	if global_position.y < despawn_below_y:
		queue_free()
		return

	_try_find_mario()

	_stomp_timer = maxf(_stomp_timer - delta, 0.0)

	_check_mario_stomp()

	if state == State.SQUISHED:
		return

	match state:
		State.IDLE:
			_act_idle(delta)

		State.WALK_START:
			_act_walk_start(delta)

		State.WALK:
			_act_walk(delta)

		State.WALK_STOP:
			_act_walk_stop(delta)

		State.FLEE:
			_act_flee(delta)

		State.SLIDE:
			_act_slide(delta)

		State.GET_UP:
			_act_get_up(delta)

		State.RACE:
			_act_race(delta)

	_integrate(delta)
	_face_move_dir(delta)


# --- raycast physics ---------------------------------------------------------

func _integrate(delta: float) -> void:
	var space := get_world_3d().direct_space_state

	# Gravity.
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -max_fall_speed)

	# Horizontal movement + wall rays.
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_velocity.length()

	_hit_wall = false

	if speed > 0.01:
		var total := speed * delta
		var steps := maxi(1, ceili(total / MAX_STEP))
		var sub := total / float(steps)

		for i in steps:
			var cur := Vector3(velocity.x, 0.0, velocity.z)
			var cur_speed := cur.length()

			if cur_speed < 0.01:
				break

			var dir := cur / cur_speed

			var from := global_position + Vector3.UP * wall_ray_height

			var query := PhysicsRayQueryParameters3D.create(
				from,
				from + dir * (koopa_radius + sub)
			)

			query.collision_mask = wall_mask

			var hit := space.intersect_ray(query)

			if hit:
				var n: Vector3 = hit.normal

				if n.y < _max_floor_normal_y:
					_hit_wall = true
					_wall_normal = n

					var hp: Vector3 = hit.position

					var d := Vector2(
						from.x - hp.x,
						from.z - hp.z
					).length()

					global_position += dir * maxf(
						d - koopa_radius,
						0.0
					)

					var bounced := cur.bounce(n)

					velocity.x = bounced.x * wall_bounce_damping
					velocity.z = bounced.z * wall_bounce_damping

					# The heading changed, so let the edge query refresh.
					_edge_check_timer = 0.0

					continue

			global_position += dir * sub

	# Vertical movement + floor snap ray.
	var drop := velocity.y * delta

	if velocity.y <= 0.0:
		var from := global_position + Vector3.UP * floor_ray_up

		var reach := floor_ray_up + maxf(
			floor_snap,
			-drop + 0.05
		)

		var query := PhysicsRayQueryParameters3D.create(
			from,
			from + Vector3.DOWN * reach
		)

		query.collision_mask = floor_mask

		var fh := space.intersect_ray(query)

		if fh:
			global_position.y = (fh.position as Vector3).y
			velocity.y = 0.0
			_grounded = true
		else:
			global_position.y += drop
			_grounded = false
	else:
		global_position.y += drop
		_grounded = false


## Cached floor-ahead query.
##
## Instead of raycasting every physics frame, the query is refreshed when:
##
## 1. The cache timer expires.
## 2. The Koopa moved far enough.
## 3. The Koopa turned enough.
##
## This massively reduces physics queries when several Koopas are walking.
func _floor_ahead(delta: float = 0.0) -> bool:
	_edge_check_timer -= delta

	var moved := (
		global_position.distance_squared_to(_edge_check_position)
		>= edge_check_move_distance * edge_check_move_distance
	)

	var turned := (
		absf(angle_difference(_target_yaw, _edge_check_yaw))
		>= edge_check_turn_threshold
	)

	if _edge_check_timer > 0.0 and not moved and not turned:
		return _floor_ahead_cached

	_edge_check_timer = edge_check_interval
	_edge_check_position = global_position
	_edge_check_yaw = _target_yaw

	var dir := Vector3(
		sin(_target_yaw),
		0.0,
		cos(_target_yaw)
	)

	var from := (
		global_position
		+ dir * edge_check_distance
		+ Vector3.UP * floor_ray_up
	)

	var to := from + Vector3.DOWN * (
		floor_ray_up + edge_drop_depth
	)

	var query := PhysicsRayQueryParameters3D.create(
		from,
		to
	)

	query.collision_mask = floor_mask

	_floor_ahead_cached = not (
		get_world_3d()
		.direct_space_state
		.intersect_ray(query)
		.is_empty()
	)

	return _floor_ahead_cached


# --- behaviour ---------------------------------------------------------------

func _enter_idle() -> void:
	state = State.IDLE

	_timer = randf_range(
		idle_time.x,
		idle_time.y
	)

	_play_anim(anim_idle)


func _act_idle(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		acceleration * delta
	)

	_timer -= delta

	if _timer <= 0.0:
		_target_yaw = (
			rotation.y
			+ deg_to_rad(45.0)
			* (1.0 if randf() < 0.5 else -1.0)
		)

		_timer = 1.0
		state = State.WALK_START
		_play_anim(anim_walk_start)

	_check_run_from_mario()


func _act_walk_start(delta: float) -> void:
	var target_speed := walk_speed if is_shelled else run_speed

	var dir := Vector3(
		sin(_target_yaw),
		0.0,
		cos(_target_yaw)
	)

	velocity.x = move_toward(
		velocity.x,
		dir.x * target_speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		dir.z * target_speed,
		acceleration * delta
	)

	_timer -= delta

	if _anim_done() or _timer <= 0.0:
		state = State.WALK
		_timer = randf_range(
			walk_time.x,
			walk_time.y
		)


func _act_walk(delta: float) -> void:
	var target_speed := walk_speed if is_shelled else run_speed
	var loop_anim := anim_walk if is_shelled else anim_run

	var dir := Vector3(
		sin(_target_yaw),
		0.0,
		cos(_target_yaw)
	)

	velocity.x = move_toward(
		velocity.x,
		dir.x * target_speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		dir.z * target_speed,
		acceleration * delta
	)

	# Wall / edge handling.
	if _hit_wall:
		var bounced := Vector3(
			velocity.x,
			0.0,
			velocity.z
		).bounce(_wall_normal)

		_target_yaw = (
			atan2(bounced.x, bounced.z)
			+ randf_range(-0.4, 0.4)
		)

		# Heading changed, so force a fresh edge query.
		_edge_check_timer = 0.0

	elif not _floor_ahead(delta):
		_target_yaw += (
			PI
			* randf_range(0.75, 1.25)
			* (1.0 if randf() < 0.5 else -1.0)
		)

		# Heading changed, so force a fresh edge query.
		_edge_check_timer = 0.0

	var speed := Vector3(
		velocity.x,
		0.0,
		velocity.z
	).length()

	_play_anim(
		loop_anim,
		clampf(
			speed * anim_speed_scale,
			0.5,
			2.5
		)
	)

	_play_footsteps(delta, speed)

	_timer -= delta

	if _timer <= 0.0:
		_timer = 1.0
		state = State.WALK_STOP
		_play_anim(anim_walk_stop)

	_check_run_from_mario()


func _act_walk_stop(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		acceleration * delta
	)

	_timer -= delta

	if _anim_done() or _timer <= 0.0:
		_enter_idle()

	_check_run_from_mario()


func _act_flee(delta: float) -> void:
	_play_anim(
		anim_flee if is_shelled else anim_run,
		1.2
	)

	_play_footsteps(
		delta,
		flee_speed
	)

	var dir := Vector3(
		sin(_target_yaw),
		0.0,
		cos(_target_yaw)
	)

	velocity.x = move_toward(
		velocity.x,
		dir.x * flee_speed,
		acceleration * 2.0 * delta
	)

	velocity.z = move_toward(
		velocity.z,
		dir.z * flee_speed,
		acceleration * 2.0 * delta
	)

	if _hit_wall:
		var bounced := Vector3(
			velocity.x,
			0.0,
			velocity.z
		).bounce(_wall_normal)

		_target_yaw = atan2(
			bounced.x,
			bounced.z
		)

		_edge_check_timer = 0.0

	if _mario:
		var to_mario: Vector3 = (
			_mario.global_transform.origin
			- global_position
		)

		to_mario.y = 0.0

		if (
			to_mario.length_squared()
			> flee_give_up_distance * flee_give_up_distance
		):
			_enter_idle()
	else:
		_enter_idle()


func _act_slide(delta: float) -> void:
	if _grounded:
		var horiz := Vector2(
			velocity.x,
			velocity.z
		)

		var speed := move_toward(
			horiz.length(),
			0.0,
			slide_friction * delta
		)

		horiz = (
			horiz.normalized() * speed
			if speed > 0.01
			else Vector2.ZERO
		)

		velocity.x = horiz.x
		velocity.z = horiz.y

	if Vector2(
		velocity.x,
		velocity.z
	).length() <= slide_stop_speed:
		_timer = 1.0
		state = State.GET_UP
		_play_anim(anim_stand_up)


func _act_get_up(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		acceleration * delta
	)

	_timer -= delta

	if _anim_done() or _timer <= 0.0:
		if is_shelled:
			_enter_idle()
		else:
			state = State.WALK
			_timer = randf_range(
				walk_time.x,
				walk_time.y
			)


# --- race --------------------------------------------------------------------

func start_race() -> void:
	_waypoint = 0
	state = State.RACE


func _act_race(delta: float) -> void:
	if _waypoint >= race_path.size():
		state = State.IDLE
		race_finished.emit()
		return

	_land_timer = maxf(
		_land_timer - delta,
		0.0
	)

	var target := race_path[_waypoint]

	var to_target := target - global_position
	to_target.y = 0.0

	var waypoint_distance_sq := (
		waypoint_reach_distance
		* waypoint_reach_distance
	)

	if to_target.length_squared() < waypoint_distance_sq:
		_waypoint += 1
		return

	_target_yaw = atan2(
		to_target.x,
		to_target.z
	)

	var dir := Vector3(
		sin(_target_yaw),
		0.0,
		cos(_target_yaw)
	)

	velocity.x = move_toward(
		velocity.x,
		dir.x * race_speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		dir.z * race_speed,
		acceleration * delta
	)

	if _grounded and (
		_hit_wall
		or not _floor_ahead(delta)
	):
		velocity.y = race_hop_speed
		_race_air = true

		_play_anim(
			anim_jump,
			1.0,
			0.05
		)

	elif _race_air and _grounded:
		_race_air = false
		_land_timer = 0.25

		_play_anim(
			anim_land,
			1.0,
			0.05
		)

	elif _grounded and _land_timer <= 0.0:
		_play_anim(
			anim_walk,
			2.2
		)

	_play_footsteps(
		delta,
		race_speed
	)


# --- stomp handling ----------------------------------------------------------

func _check_mario_stomp() -> void:
	if _mario == null or _stomp_timer > 0.0:
		return

	var mario_pos: Vector3 = (
		_mario.global_transform.origin
	)

	var to_mario := mario_pos - global_position
	to_mario.y = 0.0

	if (
		to_mario.length_squared()
		> stomp_radius * stomp_radius
	):
		return

	var mario_feet_y := (
		mario_pos.y
		+ mario_feet_offset
	)

	var top_y := (
		global_position.y
		+ koopa_top_height
	)

	if (
		mario_feet_y < top_y - 0.35
		or mario_feet_y > top_y + stomp_vertical_window
	):
		return

	if "velocity" in _mario and _mario.velocity.y > -2.0:
		return

	_stomp_timer = stomp_cooldown

	_bounce_mario()

	if is_shelled:
		_pop_shell()
	else:
		_squish_die()


func _pop_shell() -> void:
	is_shelled = false

	_shellless_mesh.show()
	_apply_shell_state()

	shell_popped.emit()

	LibSM64.play_sound(
		LibSM64.SOUND_OBJ_KOOPA_DAMAGE,
		global_position
	)

	state = State.SLIDE

	var yaw := randf_range(
		0.0,
		TAU
	)

	var dir := Vector3(
		sin(yaw),
		0.0,
		cos(yaw)
	)

	velocity.x = (
		dir.x
		* slide_launch_force
	)

	velocity.z = (
		dir.z
		* slide_launch_force
	)

	velocity.y = slide_pop_up_speed

	rotation.y = (
		atan2(dir.x, dir.z)
		+ model_yaw_offset
	)

	_play_anim(anim_lay_unshelled)


func _squish_die() -> void:
	state = State.SQUISHED
	velocity = Vector3.ZERO

	squished.emit()

	LibSM64.play_sound(
		LibSM64.SOUND_OBJ_KOOPA_FLYGUY_DEATH,
		global_position
	)

	_spawn_coin()

	for p in [
		_shelled_anim,
		_shellless_anim
	]:
		if p:
			p.pause()

	for mesh in [
		_shellless_mesh,
		_shelled_mesh
	]:
		if mesh:
			var tw := create_tween()

			tw.tween_property(
				mesh,
				"scale",
				Vector3(1.6, 0.15, 1.6),
				0.08
			)

	var despawn := create_tween()

	despawn.tween_interval(0.5)
	despawn.tween_callback(queue_free)


func _bounce_mario() -> void:
	if _mario and "velocity" in _mario:
		_mario.velocity.y = mario_stomp_bounce


func _spawn_coin() -> void:
	var coin: Coin3D

	if coin_scene != null:
		coin = coin_scene.instantiate() as Coin3D
	else:
		coin = Coin3D.new()

	coin.moving_coin = true

	get_parent().add_child(coin)

	coin.global_position = (
		global_position
		+ Vector3.UP * 0.6
	)


# --- helpers -----------------------------------------------------------------

func _check_run_from_mario() -> bool:
	if _mario == null:
		return false

	var to_mario: Vector3 = (
		_mario.global_transform.origin
		- global_position
	)

	to_mario.y = 0.0

	if (
		to_mario.length_squared()
		> flee_trigger_distance * flee_trigger_distance
		or to_mario.is_zero_approx()
	):
		return false

	var facing := Vector3(
		sin(rotation.y),
		0.0,
		cos(rotation.y)
	)

	if (
		facing.dot(to_mario.normalized())
		< cos(deg_to_rad(flee_facing_cone_deg))
	):
		return false

	_target_yaw = atan2(
		-to_mario.x,
		-to_mario.z
	)

	state = State.FLEE

	# The heading changed significantly, so don't use an old
	# edge result after fleeing starts.
	_edge_check_timer = 0.0

	return true


func _apply_shell_state() -> void:
	if _shelled_mesh:
		_shelled_mesh.visible = is_shelled

	if _shellless_mesh:
		_shellless_mesh.visible = not is_shelled


## Resolves a base animation name on a specific AnimationPlayer.
func _resolve_anim(
	player: AnimationPlayer,
	base: String
) -> StringName:
	if player == null:
		return &""

	var key := [
		player.get_instance_id(),
		base
	]

	if _anim_cache.has(key):
		return _anim_cache[key]

	var resolved := &""

	if player.has_animation(base):
		resolved = base
	else:
		for anim_name in player.get_animation_list():
			var suffix := anim_name.get_slice(
				"|",
				anim_name.get_slice_count("|") - 1
			)

			if suffix == base or anim_name.ends_with(base):
				resolved = anim_name
				break

	_anim_cache[key] = resolved

	return resolved


## Plays the animation on both players so the hidden mesh stays synchronized.
func _play_anim(
	base: String,
	speed := 1.0,
	blend := 0.15
) -> void:
	for p in [
		_shelled_anim,
		_shellless_anim
	]:
		if p == null:
			continue

		var resolved := _resolve_anim(
			p,
			base
		)

		if resolved != &"":
			p.play(
				resolved,
				blend,
				speed
			)


func _set_loop(
	base: String,
	looped: bool
) -> void:
	for p in [
		_shelled_anim,
		_shellless_anim
	]:
		if p == null:
			continue

		var resolved := _resolve_anim(
			p,
			base
		)

		if resolved != &"":
			p.get_animation(resolved).loop_mode = (
				Animation.LOOP_LINEAR
				if looped
				else Animation.LOOP_NONE
			)


func _anim_done() -> bool:
	for p in [
		_shelled_anim,
		_shellless_anim
	]:
		if p and p.is_playing():
			return false

	return true


func _play_footsteps(
	delta: float,
	move_speed: float
) -> void:
	_footstep_timer -= (
		delta
		* maxf(move_speed, 0.1)
	)

	if _footstep_timer <= 0.0:
		_footstep_timer = 1.6

		LibSM64.play_sound(
			LibSM64.SOUND_OBJ_KOOPA_WALK,
			global_position
		)


func _face_move_dir(delta: float) -> void:
	var horiz := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	if horiz.length_squared() < 0.04:
		return

	var target_yaw := (
		atan2(
			horiz.x,
			horiz.z
		)
		+ model_yaw_offset
	)

	rotation.y = lerp_angle(
		rotation.y,
		target_yaw,
		clampf(
			turn_speed * delta,
			0.0,
			1.0
		)
	)


func _try_find_mario() -> void:
	if is_instance_valid(_mario):
		return

	_mario = (
		get_parent()
		.get_node_or_null("LibSM64Mario")
		as LibSM64Mario
	)

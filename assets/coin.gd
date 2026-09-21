@icon("res://assets/coin3d.svg")
class_name Coin3D
extends MeshInstance3D

const MAX_STEP := 0.5  # max raycast distance per substep, in meters
const SKIN := 0.01     # lift off surfaces so rays never start inside geometry

const BLINK_START_SEC := 400.0 / 60.0        # blink after 400 frames
const BLINK_TOGGLE_SEC := 4.0 / 60.0         # flip visibility every 4 frames
const DESPAWN_SEC := INF                     # effectively never despawn

@export_group("Collection")
@export var give_radius := 2.0
@export var meshwc: GeometryInstance3D
@export var coin_amount: int = 1
@export var red_coin : bool = false
@export var blue_coin : bool = false
@export var yellow_coin : bool = true

@export_group("Moving Coin Mode")
@export var moving_coin := false
@export var gravity := 30.0
@export var bounce_damping := 0.5
@export var ground_friction := 0.85
@export var drop_sound := LibSM64.SOUND_GENERAL_COIN_DROP

@export_group("Hitbox")
## Full extents of the hitbox. Vertical range runs from
## (origin.y + hitbox_bottom_offset) up by hitbox_size.y.
@export var hitbox_size := Vector3(1.0, 2.327, 1.0)
@export var mario_center_height := 0.8

## Distance from Coin3D's origin down to the bottom of the hitbox.
@export var hitbox_bottom_offset := -1.026

@export_group("Sprite")
@export var sprite_frames_file: SpriteFrames = preload("res://assets/coin_rotation_frames.tres")
@export var sprite_frames_file_2: SpriteFrames = preload("res://assets/spriteframes/spriteframes_particles.tres")
@export var sprite_color: Color = Color("#e3e300")
@export var sprite_color_2: Color = Color("#E60003")
@export var sprite_color_3: Color = Color("#6D6DE8")
@export var sprite_pixel_size := 0.0013
@export var sprite_pixel_size_2 := 0.002
@export var animationname := "rotation"

## Sprite center offset from the origin.
@export var sprite_offset_y := -0.513

## Half the coin's visual height.
@export var coin_half_height := 0.513

## Extra nudge on the floor ray only.
@export var ray_extra_offset := 0.0

var _used := false
var _velocity := Vector3.ZERO
var _grounded := false
var _bounce_count := 0
var _lifetime := 0.0
var _blink_timer := 0.0
var sprite: AnimatedSprite3D

var _mario: LibSM64Mario = null


func _ready() -> void:
	_try_find_mario()

	sprite = AnimatedSprite3D.new()
	add_child(sprite)
	if yellow_coin:
		sprite.modulate = sprite_color
	elif red_coin:
		sprite.modulate = sprite_color_2
	elif blue_coin:
		sprite.modulate = sprite_color_3
	else:
		sprite.modulate = sprite_color
	sprite.sprite_frames = sprite_frames_file
	if yellow_coin || red_coin:
		sprite.pixel_size = sprite_pixel_size
	if blue_coin:
		sprite.pixel_size = sprite_pixel_size_2
	else:
		sprite.pixel_size = sprite_pixel_size
	sprite.centered = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.animation = animationname
	sprite.position.y = sprite_offset_y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.play()

	if moving_coin:
		_init_moving_coin()


func _try_find_mario() -> void:
	if is_instance_valid(_mario):
		return

	_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario


func _init_moving_coin() -> void:
	var yaw := randf_range(0.0, TAU)
	var forward_speed := randf_range(0.0, 10.0)

	_velocity.x = sin(yaw) * forward_speed
	_velocity.z = cos(yaw) * forward_speed
	_velocity.y = randf_range(0.0, 10.0) + 30.0


func _physics_process(delta: float) -> void:
	if _used:
		return

	_try_find_mario()

	if moving_coin:
		_process_moving_coin(delta)

	if not _mario:
		return

	if _mario_in_hitbox():
		_use_coin()


func _mario_in_hitbox() -> bool:
	if not _mario:
		return false

	var mario_center := _mario.global_transform.origin + Vector3(0, mario_center_height, 0)
	var delta := mario_center - global_transform.origin

	var half_x := hitbox_size.x * 0.5
	var half_z := hitbox_size.z * 0.5

	if absf(delta.x) > half_x or absf(delta.z) > half_z:
		return false

	var local_y := delta.y - hitbox_bottom_offset

	if local_y < 0.0 or local_y > hitbox_size.y:
		return false

	return true


func _process_moving_coin(delta: float) -> void:
	_velocity.y -= gravity * delta

	var space_state := get_world_3d().direct_space_state

	var ray_offset := Vector3(
		0,
		sprite_offset_y - coin_half_height + ray_extra_offset - 0.013,
		0
	)

	var total_motion := _velocity * delta
	var steps := maxi(1, ceili(total_motion.length() / MAX_STEP))
	var step_motion := total_motion / float(steps)

	for i in steps:
		var from := global_transform.origin + ray_offset
		var to := from + step_motion

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]

		var hit := space_state.intersect_ray(query)

		if hit:
			var normal: Vector3 = hit.normal

			global_transform.origin = hit.position - ray_offset + normal * SKIN

			var horiz := Vector3(_velocity.x, 0.0, _velocity.z)
			var reflected := horiz.bounce(normal)

			_velocity.x = reflected.x * 0.7
			_velocity.z = reflected.z * 0.7

			if normal.y > 0.5 and _velocity.y < 0.0:
				_on_ground_contact(normal)
			elif normal.y < -0.5 and _velocity.y > 0.0:
				_velocity.y = 0.0

			break
		else:
			global_transform.origin += step_motion

	var floor_from := global_transform.origin + ray_offset

	var floor_query := PhysicsRayQueryParameters3D.create(
		floor_from,
		floor_from + Vector3.DOWN * MAX_STEP
	)

	floor_query.exclude = [self]

	var floor_hit := space_state.intersect_ray(floor_query)

	if floor_hit and _velocity.y <= 0.0:
		global_transform.origin = (
			floor_hit.position
			- ray_offset
			+ floor_hit.normal * SKIN
		)

		_on_ground_contact(floor_hit.normal)

	elif not floor_hit:
		_grounded = false
		_bounce_count = 0

	if _grounded and abs(_velocity.x) + abs(_velocity.z) > 0.01:
		var horiz_dir := Vector3(_velocity.x, 0.0, _velocity.z)

		if horiz_dir.length() > 0.01:
			var target_yaw := atan2(horiz_dir.x, horiz_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.4)

	_lifetime += delta

	if _lifetime > BLINK_START_SEC:
		_blink_timer += delta

		if fmod(_blink_timer, BLINK_TOGGLE_SEC) < delta:
			_set_all_visible(not visible)

		if _lifetime > DESPAWN_SEC:
			queue_free()


func _on_ground_contact(normal: Vector3) -> void:
	var impact := -_velocity.y

	if impact > 3.0 and _bounce_count < 5:
		_velocity.y = impact * bounce_damping
		_bounce_count += 1
		LibSM64.play_sound(drop_sound, global_transform.origin)
		_grounded = false
	else:
		_velocity.y = 0.0
		_velocity.x *= ground_friction
		_velocity.z *= ground_friction

		if abs(_velocity.x) + abs(_velocity.z) < 0.05:
			_velocity.x = 0.0
			_velocity.z = 0.0

		_grounded = true


func _set_all_visible(value: bool) -> void:
	visible = value

	if sprite:
		sprite.visible = value

	if meshwc:
		meshwc.visible = value


func _use_coin() -> void:
	if _used:
		return

	_used = true

	if _mario:
		var cam: Vector3 = %CameraRig.global_position
		var sound_pos := cam if %CameraRig else _mario.global_position

		var new_coin_count: int = _mario.coin_count + coin_amount
		new_coin_count = _mario.coin_count

		LibSM64.mario_heal(
			_mario._id,
			coin_amount * 0x0110
		)
		

		if yellow_coin:
			LibSM64.play_sound(
				LibSM64.SOUND_GENERAL_COIN,
				sound_pos
			)
		elif red_coin:
			LibSM64.play_sound(LibSM64.SOUND_MENU_COLLECT_RED_COIN, sound_pos)
		elif blue_coin:
			for i in coin_amount:
				LibSM64.play_sound(LibSM64.SOUND_GENERAL_COIN, sound_pos)
				await get_tree().create_timer(0.2).timeout

	_set_all_visible(false)
	_on_used()


func _on_used() -> void:
	pass

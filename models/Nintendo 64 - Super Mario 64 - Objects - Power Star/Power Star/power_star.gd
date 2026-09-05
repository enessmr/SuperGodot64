@icon("res://models/PowerStar_ICON.svg")
class_name PowerStar3D
extends Node3D

@onready var area_3d: Area3D = $Area3D
@onready var particle = %Sparkles

@export var give_radius := 2.0
@export var anim: AnimationPlayer

@export_category("Star")
@export var star_id := 1

@export_category("Star Spawn")
@export var star_spawn_height_curve: Curve
@export var star_spawn_horizontal_curve: Curve
@export var star_spawn_duration := 1.0
@export var star_spawn_offset := 3.0

var _star_spawn_active := false
var _star_spawn_time := 0.0

var _star_spawn_old_pos := Vector3.ZERO
var _star_spawn_target_pos := Vector3.ZERO

var _mario: LibSM64Mario = null
var _camera_rig: Node3D = null
var _camera_3d: Camera3D = null
var _camera_star_grab: Node3D = null

var _is_collected := false
var _star_grab_active := false


func _ready() -> void:
	area_3d.area_entered.connect(_on_area_3d_area_entered)

	if star_spawn_height_curve == null:
		star_spawn_height_curve = _make_default_height_curve()

	if star_spawn_horizontal_curve == null:
		star_spawn_horizontal_curve = _make_default_horizontal_curve()

	_find_mactors_and_camera()


func _find_mactors_and_camera() -> void:
	if not is_instance_valid(_mario):
		_mario = get_tree().current_scene.find_child(
			"LibSM64Mario",
			true,
			false
		) as LibSM64Mario

	if not is_instance_valid(_camera_rig):
		_camera_rig = get_tree().current_scene.find_child(
			"CameraRig",
			true,
			false
		)

	if is_instance_valid(_camera_rig) and not is_instance_valid(_camera_3d):
		_camera_3d = _camera_rig.find_child(
			"Camera3D",
			true,
			false
		) as Camera3D

	if not is_instance_valid(_camera_star_grab):
		_camera_star_grab = get_tree().current_scene.find_child(
			"Camera_StarGrab",
			true,
			false
		)


func _process(delta: float) -> void:
	if _star_spawn_active:
		_update_star_spawn(delta)
	else:
		rotation_degrees.y += 180.0 * delta

		if visible and not _is_collected:
			if not is_instance_valid(_mario):
				_find_mactors_and_camera()

			if is_instance_valid(_mario):
				var dist: float = global_position.distance_to(
					_mario.global_position
				)

				if dist <= give_radius:
					_try_collect(_mario)


func play_star_spawn_animation(spawn_pos: Variant = null) -> void:
	_find_mactors_and_camera()

	if star_spawn_height_curve == null:
		star_spawn_height_curve = _make_default_height_curve()

	if star_spawn_horizontal_curve == null:
		star_spawn_horizontal_curve = _make_default_horizontal_curve()

	if spawn_pos is Vector3:
		global_position = spawn_pos

	_star_spawn_target_pos = position

	_star_spawn_old_pos = _star_spawn_target_pos + Vector3(
		0.0,
		-star_spawn_offset,
		0.0
	)

	_star_spawn_time = 0.0
	_star_spawn_active = true

	position = _star_spawn_old_pos

	area_3d.set_deferred("monitoring", false)
	area_3d.set_deferred("monitorable", false)

	if is_instance_valid(_mario):
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_instance_valid(_mario):
				_play_star_spawn_sounds()
				CONNECT_ONE_SHOT
		)

func _play_star_spawn_sounds() -> void:
	if not is_instance_valid(_mario):
		return

	LibSM64.play_sound(
		LibSM64.SOUND_GENERAL_STAR_APPEARS,
		_mario.global_position
	)

	await get_tree().create_timer(0.3).timeout

	if not is_instance_valid(_mario):
		return

	LibSM64.play_music(
		LibSM64.SEQ_PLAYER_LEVEL,
		LibSM64.SEQ_EVENT_CUTSCENE_STAR_SPAWN
	)


func _update_star_spawn(delta: float) -> void:
	_star_spawn_time += delta

	var ratio: float = clampf(
		_star_spawn_time / star_spawn_duration,
		0.0,
		1.0
	)

	var height_value: float = (
		star_spawn_height_curve.sample_baked(ratio)
	)

	var horizontal_value: float = (
		star_spawn_horizontal_curve.sample_baked(ratio)
	)

	position.x = lerpf(
		_star_spawn_old_pos.x,
		_star_spawn_target_pos.x,
		horizontal_value
	)

	position.y = lerpf(
		_star_spawn_old_pos.y,
		_star_spawn_target_pos.y,
		height_value
	)

	position.z = lerpf(
		_star_spawn_old_pos.z,
		_star_spawn_target_pos.z,
		horizontal_value
	)

	rotation_degrees.y += 360.0 * delta

	if ratio >= 1.0:
		_star_spawn_active = false
		_activate_star()


func _activate_star() -> void:
	visible = true

	area_3d.set_deferred("monitoring", true)
	area_3d.set_deferred("monitorable", true)


func _try_collect(mario: LibSM64Mario) -> void:
	if _is_collected or _star_grab_active:
		return

	if not visible or not is_instance_valid(mario):
		return

	_is_collected = true
	_star_grab_active = true
	_mario = mario

	# Stop Mario's forward movement immediately.
	_mario.forward_velocity = 0.0

	# Hide the star immediately.
	_collect()

	# Begin the collection sequence.
	_start_star_grab()


func _collect() -> void:
	area_3d.set_deferred("monitoring", false)
	area_3d.set_deferred("monitorable", false)

	visible = false


func _start_star_grab() -> void:
	if not is_instance_valid(_mario):
		_star_grab_active = false
		return

	_find_mactors_and_camera()

	if not is_instance_valid(_camera_rig):
		_star_grab_active = false
		return

	if not is_instance_valid(_camera_star_grab):
		_star_grab_active = false
		return

	# Save the camera rig's original transform.
	var rig_orig_transform: Transform3D = _camera_rig.global_transform

	# Save process modes.
	var mario_old_mode := _mario.process_mode
	var rig_old_mode := _camera_rig.process_mode

	var cam_old_mode := (
		_camera_3d.process_mode
		if is_instance_valid(_camera_3d)
		else Node.PROCESS_MODE_INHERIT
	)

	# Mario MUST remain active here.
	# LibSM64 needs to continue running so Mario can actually land.
	await _wait_for_mario_to_land()

	if not is_instance_valid(_mario):
		return

	if not is_instance_valid(_camera_rig):
		return

	if not is_instance_valid(_camera_star_grab):
		_find_mactors_and_camera()

	if not is_instance_valid(_camera_star_grab):
		return

	# Star collection sound.
	LibSM64.play_sound(
		LibSM64.SOUND_MENU_STAR_SOUND,
		_mario.global_position
	)

	# Move CameraRig to Camera_StarGrab.
	var target_pos: Vector3 = _camera_star_grab.global_position

	var tween := get_tree().create_tween()

	tween.tween_property(
		_camera_rig,
		"global_position",
		target_pos,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	if not is_instance_valid(_mario):
		return

	if not is_instance_valid(_camera_rig):
		return

	# Make the CAMERA RIG itself face Mario.
	# CameraRig uses -Z as its forward direction.
	_camera_rig.look_at(
		_mario.global_position,
		Vector3.UP
	)

	# Start Mario's star dance only after the camera is positioned
	# and facing him.
	LibSM64.set_mario_action(
		_mario.id,
		LibSM64.ACT_STAR_DANCE_EXIT
	)

	# Star dance / collection music.
	LibSM64.play_music(
		LibSM64.SEQ_PLAYER_LEVEL,
		LibSM64.SEQ_EVENT_CUTSCENE_COLLECT_STAR
	)

	# Sparkles.
	particle.emitting = true

	await get_tree().create_timer(0.4).timeout

	if is_instance_valid(particle):
		particle.emitting = false

	# Mario's "Here we go!" sound.
	await get_tree().create_timer(1.0).timeout

	if is_instance_valid(_mario):
		LibSM64.play_sound(
			LibSM64.SOUND_MARIO_HERE_WE_GO,
			_mario.global_position
		)

	# Let the star dance/cutscene play.
	await get_tree().create_timer(3.0).timeout

	# Extra delay before returning control.
	await get_tree().create_timer(0.3).timeout

	# Restore the original camera transform.
	if is_instance_valid(_camera_rig):
		_camera_rig.global_transform = rig_orig_transform

	# Restore processing.
	if is_instance_valid(_mario):
		_mario.process_mode = mario_old_mode

	if is_instance_valid(_camera_rig):
		_camera_rig.process_mode = rig_old_mode

	if is_instance_valid(_camera_3d):
		_camera_3d.process_mode = cam_old_mode

	_star_grab_active = false


func _wait_for_mario_to_land() -> void:
	# Do NOT disable Mario before this function.
	# LibSM64 needs to keep updating Mario's physics.

	var safety_time: float = 0.0

	while safety_time < 5.0:
		if not is_instance_valid(_mario):
			return

		var delta: float = get_process_delta_time()
		safety_time += delta

		# Mario has stopped moving vertically.
		#
		# A small delay prevents the cutscene from triggering
		# on a frame where Mario happens to have zero Y velocity
		# before actually touching the ground.
		if absf(_mario.velocity.y) <= 0.01:
			await get_tree().process_frame

			if not is_instance_valid(_mario):
				return

			if absf(_mario.velocity.y) <= 0.01:
				break

		await get_tree().process_frame


func _on_area_3d_area_entered(area: Area3D) -> void:
	var mario := area.get_parent() as LibSM64Mario

	if mario:
		_try_collect(mario)


func _make_default_height_curve() -> Curve:
	var curve := Curve.new()

	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.25, 0.15))
	curve.add_point(Vector2(0.5, 0.65))
	curve.add_point(Vector2(0.75, 0.9))
	curve.add_point(Vector2(1.0, 1.0))

	return curve


func _make_default_horizontal_curve() -> Curve:
	var curve := Curve.new()

	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 0.35))
	curve.add_point(Vector2(1.0, 1.0))

	return curve

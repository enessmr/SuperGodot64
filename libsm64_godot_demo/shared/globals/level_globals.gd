extends Node

func star_spawn(
	star: Node3D,
	desired_point: Marker3D,
	camera: Node3D,
	mario: Node3D,
	is_vertical: bool = false,
	star_type: int = 2
) -> void:
	# Let this script handle the star's spinning.
	star._star_spawn_active = false

	# Make the star visible immediately.
	star.visible = true

	var original_transform := camera.global_transform

	# --- PAUSE MARIO ---
	var mario_old_process_mode := mario.process_mode
	mario.process_mode = Node.PROCESS_MODE_DISABLED

	# ---------------------------------------------------------
	# STAR SPAWN SOUND / MUSIC
	# ---------------------------------------------------------

	match star_type:
		1:
			# Type 1: Bosses, etc.
			LibSM64.play_sound(
				LibSM64.SOUND_ENV_STAR,
				star.global_position
			)

		2:
			# Type 2: Yellow boxes, etc.
			LibSM64.play_sound(
				LibSM64.SOUND_GENERAL_STAR_APPEARS,
				star.global_position
			)

			star.visible = true

			await get_tree().create_timer(0.8).timeout

			if not is_instance_valid(star):
				return

			LibSM64.play_music(
				LibSM64.SEQ_PLAYER_ENV,
				LibSM64.SEQ_EVENT_CUTSCENE_STAR_SPAWN
			)

	# Make sure the star is visible after the sound delay.
	star.visible = true

	# ---------------------------------------------------------
	# MOVE CAMERA TO STAR
	# ---------------------------------------------------------

	var camera_offset := Vector3.ZERO
	var initial_camera_target := star.global_position + camera_offset

	var camera_tween := create_tween()

	camera_tween.tween_property(
		camera,
		"global_position",
		initial_camera_target,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await camera_tween.finished

	if not is_instance_valid(star):
		return

	star.visible = true

	# ---------------------------------------------------------
	# STAR BOUNCE
	# ---------------------------------------------------------

	var star_tween := create_tween()

	if is_vertical:
		# First Bounce: Up
		star_tween.tween_property(
			star,
			"global_position",
			desired_point.global_position + Vector3.UP * 1.5,
			0.3
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# First Bounce: Down
		star_tween.tween_property(
			star,
			"global_position",
			desired_point.global_position,
			0.3
		).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		# Second Bounce: Up
		star_tween.tween_property(
			star,
			"global_position",
			desired_point.global_position + Vector3.UP * 0.75,
			0.2
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Second Bounce: Down
		star_tween.tween_property(
			star,
			"global_position",
			desired_point.global_position,
			0.2
		).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		# Normal Movement
		star_tween.tween_property(
			star,
			"global_position",
			desired_point.global_position,
			1.0
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# ---------------------------------------------------------
	# LOCK CAMERA TO STAR + SPIN STAR
	# ---------------------------------------------------------

	while star_tween.is_running():
		if not is_instance_valid(star):
			return

		# Keep the camera locked to the star.
		camera.global_position = star.global_position + camera_offset

		# Keep the star spinning independently.
		star.rotation_degrees.y += 180.0 * get_process_delta_time()

		await get_tree().process_frame

	# ---------------------------------------------------------
	# RETURN CAMERA TO ORIGINAL TRANSFORM
	# ---------------------------------------------------------

	var return_tween := create_tween()
	return_tween.set_parallel(true)

	return_tween.tween_property(
		camera,
		"global_position",
		original_transform.origin,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return_tween.tween_property(
		camera,
		"global_rotation",
		original_transform.basis.get_euler(),
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await return_tween.finished

	if not is_instance_valid(star):
		return

	# Guarantee that the camera is restored exactly.
	camera.global_transform = original_transform

	# The star is now collectible.
	star._activate_star()

	# --- UNPAUSE MARIO ---
	mario.process_mode = mario_old_process_mode

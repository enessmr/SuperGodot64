extends Node

@export_enum(
	"SEQ_SOUND_PLAYER",
	"SEQ_EVENT_CUTSCENE_COLLECT_STAR",
	"SEQ_MENU_TITLE_SCREEN",
	"SEQ_LEVEL_GRASS",
	"SEQ_LEVEL_INSIDE_CASTLE",
	"SEQ_LEVEL_WATER",
	"SEQ_LEVEL_HOT",
	"SEQ_LEVEL_BOSS_KOOPA",
	"SEQ_LEVEL_SNOW",
	"SEQ_LEVEL_SLIDE",
	"SEQ_LEVEL_SPOOKY",
	"SEQ_EVENT_PIRANHA_PLANT",
	"SEQ_LEVEL_UNDERGROUND",
	"SEQ_MENU_STAR_SELECT",
	"SEQ_EVENT_POWERUP",
	"SEQ_EVENT_METAL_CAP",
	"SEQ_EVENT_KOOPA_MESSAGE",
	"SEQ_LEVEL_KOOPA_ROAD",
	"SEQ_EVENT_HIGH_SCORE",
	"SEQ_EVENT_MERRY_GO_ROUND",
	"SEQ_EVENT_RACE",
	"SEQ_EVENT_CUTSCENE_STAR_SPAWN",
	"SEQ_EVENT_BOSS",
	"SEQ_EVENT_CUTSCENE_COLLECT_KEY",
	"SEQ_EVENT_ENDLESS_STAIRS",
	"SEQ_LEVEL_BOSS_KOOPA_FINAL",
	"SEQ_EVENT_CUTSCENE_CREDITS",
	"SEQ_EVENT_SOLVE_PUZZLE",
	"SEQ_EVENT_TOAD_MESSAGE",
	"SEQ_EVENT_PEACH_MESSAGE",
	"SEQ_EVENT_CUTSCENE_INTRO",
	"SEQ_EVENT_CUTSCENE_VICTORY",
	"SEQ_EVENT_CUTSCENE_ENDING",
	"SEQ_MENU_FILE_SELECT",
	"SEQ_EVENT_CUTSCENE_LAKITU",
	"SEQ_COUNT"
)
var music: int = 3

@export var music_index: int = 3
@export var no_music: bool = false

const VANISH_CAP_DURATION := 20.0

var _cap_timer: Timer


func _ready() -> void:
	_cap_timer = Timer.new()
	_cap_timer.one_shot = true
	_cap_timer.wait_time = VANISH_CAP_DURATION
	_cap_timer.timeout.connect(_on_cap_timer_timeout)
	add_child(_cap_timer)


func play_musik(
	start_cap: LibSM64.MarioFlags = LibSM64.MarioFlags.MARIO_NORMAL_CAP
) -> void:
	if no_music:
		return

	if (start_cap & LibSM64.MarioFlags.MARIO_METAL_CAP) != 0:
		LibSM64.play_music(
			LibSM64.SEQ_PLAYER_LEVEL,
			LibSM64.SEQ_EVENT_METAL_CAP
		)
		_cap_timer.stop()

	elif (start_cap & LibSM64.MarioFlags.MARIO_WING_CAP) != 0:
		LibSM64.play_music(
			LibSM64.SEQ_PLAYER_LEVEL,
			LibSM64.SEQ_EVENT_POWERUP
		)
		_cap_timer.stop()

	elif (start_cap & LibSM64.MarioFlags.MARIO_VANISH_CAP) != 0:
		LibSM64.play_music(
			LibSM64.SEQ_PLAYER_LEVEL,
			LibSM64.SEQ_EVENT_POWERUP
		)
		_cap_timer.start(VANISH_CAP_DURATION)

	else:
		play_level_music()


func play_level_music() -> void:
	if no_music:
		return

	var sequences: Array[int] = [
		LibSM64.SEQ_SOUND_PLAYER,
		LibSM64.SEQ_EVENT_CUTSCENE_COLLECT_STAR,
		LibSM64.SEQ_MENU_TITLE_SCREEN,
		LibSM64.SEQ_LEVEL_GRASS,
		LibSM64.SEQ_LEVEL_INSIDE_CASTLE,
		LibSM64.SEQ_LEVEL_WATER,
		LibSM64.SEQ_LEVEL_HOT,
		LibSM64.SEQ_LEVEL_BOSS_KOOPA,
		LibSM64.SEQ_LEVEL_SNOW,
		LibSM64.SEQ_LEVEL_SLIDE,
		LibSM64.SEQ_LEVEL_SPOOKY,
		LibSM64.SEQ_EVENT_PIRANHA_PLANT,
		LibSM64.SEQ_LEVEL_UNDERGROUND,
		LibSM64.SEQ_MENU_STAR_SELECT,
		LibSM64.SEQ_EVENT_POWERUP,
		LibSM64.SEQ_EVENT_METAL_CAP,
		LibSM64.SEQ_EVENT_KOOPA_MESSAGE,
		LibSM64.SEQ_LEVEL_KOOPA_ROAD,
		LibSM64.SEQ_EVENT_HIGH_SCORE,
		LibSM64.SEQ_EVENT_MERRY_GO_ROUND,
		LibSM64.SEQ_EVENT_RACE,
		LibSM64.SEQ_EVENT_CUTSCENE_STAR_SPAWN,
		LibSM64.SEQ_EVENT_BOSS,
		LibSM64.SEQ_EVENT_CUTSCENE_COLLECT_KEY,
		LibSM64.SEQ_EVENT_ENDLESS_STAIRS,
		LibSM64.SEQ_LEVEL_BOSS_KOOPA_FINAL,
		LibSM64.SEQ_EVENT_CUTSCENE_CREDITS,
		LibSM64.SEQ_EVENT_SOLVE_PUZZLE,
		LibSM64.SEQ_EVENT_TOAD_MESSAGE,
		LibSM64.SEQ_EVENT_PEACH_MESSAGE,
		LibSM64.SEQ_EVENT_CUTSCENE_INTRO,
		LibSM64.SEQ_EVENT_CUTSCENE_VICTORY,
		LibSM64.SEQ_EVENT_CUTSCENE_ENDING,
		LibSM64.SEQ_MENU_FILE_SELECT,
		LibSM64.SEQ_EVENT_CUTSCENE_LAKITU
	]

	LibSM64.play_music(
		LibSM64.SEQ_PLAYER_LEVEL,
		sequences[music_index]
	)


func _on_cap_timer_timeout() -> void:
	play_level_music()


func star_spawn(
	star: Node3D,
	desired_point: Marker3D,
	camera: Node3D,
	mario: Node3D,
	is_vertical: bool = false,
	star_type: int = 2,
	jumping: bool = false
) -> void:
	if not is_instance_valid(star):
		return

	if not is_instance_valid(desired_point):
		return

	if not is_instance_valid(camera):
		return

	if not is_instance_valid(mario):
		return

	var original_camera_transform: Transform3D = camera.global_transform
	var mario_old_process_mode: Node.ProcessMode = mario.process_mode

	# This function controls the star movement.
	star._star_spawn_active = false
	star.visible = true

	# ---------------------------------------------------------
	# PAUSE MARIO ONLY FOR JUMPING STAR SEQUENCES
	# ---------------------------------------------------------

	if jumping:
		mario.process_mode = Node.PROCESS_MODE_DISABLED

	# ---------------------------------------------------------
	# STAR SPAWN SOUND / MUSIC
	# ---------------------------------------------------------

	match star_type:
		1:
			if jumping:
				LibSM64.play_sound(
					LibSM64.SOUND_ENV_STAR,
					star.global_position
				)

		2:
			if jumping:
				LibSM64.play_sound(
					LibSM64.SOUND_GENERAL_STAR_APPEARS,
					star.global_position
				)

			await get_tree().create_timer(0.8).timeout

			if not is_instance_valid(star):
				if jumping:
					mario.process_mode = mario_old_process_mode
				return

			LibSM64.play_music(
				LibSM64.SEQ_PLAYER_ENV,
				LibSM64.SEQ_EVENT_CUTSCENE_STAR_SPAWN
			)

	# ---------------------------------------------------------
	# CAMERA
	# ---------------------------------------------------------
	# Only move the camera when jumping is enabled.
	# Normal star spawns NEVER touch the camera.

	if jumping:
		var camera_tween: Tween = create_tween()

		camera_tween.tween_property(
			camera,
			"global_position",
			star.global_position,
			0.5
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		await camera_tween.finished

		if not is_instance_valid(star):
			camera.global_transform = original_camera_transform
			mario.process_mode = mario_old_process_mode
			return

	# ---------------------------------------------------------
	# STAR MOVEMENT
	# ---------------------------------------------------------

	if jumping:
		var star_tween: Tween = create_tween()

		if is_vertical:
			star_tween.tween_property(
				star,
				"global_position",
				desired_point.global_position + Vector3.UP * 1.5,
				0.3
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			star_tween.tween_property(
				star,
				"global_position",
				desired_point.global_position,
				0.3
			).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

			star_tween.tween_property(
				star,
				"global_position",
				desired_point.global_position + Vector3.UP * 0.75,
				0.2
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			star_tween.tween_property(
				star,
				"global_position",
				desired_point.global_position,
				0.2
			).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			star_tween.tween_property(
				star,
				"global_position",
				desired_point.global_position,
				1.0
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Camera follows the star ONLY during jumping.
		while star_tween.is_running():
			if not is_instance_valid(star):
				break

			camera.global_position = star.global_position

			await get_tree().process_frame

	else:
		# Normal star spawn.
		# No camera movement whatsoever.
		star.global_position = desired_point.global_position

	# ---------------------------------------------------------
	# FINISH
	# ---------------------------------------------------------

	if not is_instance_valid(star):
		if jumping:
			camera.global_transform = original_camera_transform
			mario.process_mode = mario_old_process_mode
		return

	star.global_position = desired_point.global_position

	# The star can now be collected.
	star._activate_star()

	# ---------------------------------------------------------
	# RETURN CAMERA
	# ---------------------------------------------------------

	if jumping:
		var return_tween: Tween = create_tween()
		return_tween.set_parallel(true)

		return_tween.tween_property(
			camera,
			"global_position",
			original_camera_transform.origin,
			0.5
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		return_tween.tween_property(
			camera,
			"global_rotation",
			original_camera_transform.basis.get_euler(),
			0.5
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		await return_tween.finished

		if is_instance_valid(camera):
			camera.global_transform = original_camera_transform

		mario.process_mode = mario_old_process_mode

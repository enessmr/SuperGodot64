extends Node3D

const SM64_TO_GODOT: float = 0.01
const TARGET_FPS: float = 30.0
const FRAME_TIME: float = 1.0 / TARGET_FPS

const INTRO_FLY_TO_PIPE_END: int = 820
const INTRO_PIPE_TO_DIALOG_END: int = 250

var _intro_playing: bool = false
var _intro_stage: int = 0
var _intro_frame: int = 0
var _intro_timer: float = 0.0

var _spline_segment: int = 0
var _spline_progress: float = 0.1

# State variables for interpolation
var _current_position: Vector3 = Vector3.ZERO
var _current_focus: Vector3 = Vector3.ZERO

const INTRO_START_TO_PIPE_POSITION: Array[Vector3] = [
	Vector3(2122, 8762, 9114),
	Vector3(2122, 8762, 9114),
	Vector3(2122, 7916, 9114),
	Vector3(2122, 7916, 9114),
	Vector3(957, 5166, 8613),
	Vector3(589, 4338, 7727),
	Vector3(690, 3366, 6267),
	Vector3(-1600, 2151, 4955),
	Vector3(-1557, 232, 1283),
	Vector3(-6962, -295, 2729),
	Vector3(-6979, 131, 3246),
	Vector3(-6360, -283, 4044),
	Vector3(-5695, -334, 5264),
	Vector3(-5568, -319, 7933),
	Vector3(-3848, -200, 6278),
	Vector3(-965, -263, 6092),
	Vector3(1607, 2465, 6329),
	Vector3(2824, 180, 3548),
	Vector3(1236, 136, 945),
	Vector3(448, 136, 564),
	Vector3(448, 136, 564),
	Vector3(448, 136, 564),
	Vector3(448, 136, 564),
	Vector3(448, 136, 564)
]

const INTRO_START_TO_PIPE_FOCUS: Array[Vector3] = [
	Vector3(1753, 29800, 8999),
	Vector3(1753, 29800, 8999),
	Vector3(1753, 8580, 8999),
	Vector3(1753, 8580, 8999),
	Vector3(520, 5400, 8674),
	Vector3(122, 4437, 7875),
	Vector3(316, 3333, 6538),
	Vector3(-1526, 2189, 5448),
	Vector3(-1517, 452, 1731),
	Vector3(-6659, -181, 3109),
	Vector3(-6649, 183, 3618),
	Vector3(-6009, -214, 4395),
	Vector3(-5258, -175, 5449),
	Vector3(-5158, -266, 7651),
	Vector3(-3351, -192, 6222),
	Vector3(-483, -137, 6060),
	Vector3(1833, 2211, 5962),
	Vector3(3022, 207, 3090),
	Vector3(1250, 197, 449),
	Vector3(248, 191, 227),
	Vector3(48, 191, 227),
	Vector3(48, 191, 227),
	Vector3(48, 191, 227),
	Vector3(48, 191, 227)
]

const INTRO_START_TO_PIPE_FOCUS_SPEED: Array[float] = [
	50.0, 50.0, 50.0, 100.0, 50.0, 50.0, 50.0, 36.0, 50.0, 50.0,
	17.0, 20.0, 50.0, 36.0, 26.0, 25.0, 100.0, 26.0, 20.0, 50.0,
	0.0, 0.0, 0.0
]

const INTRO_PIPE_TO_DIALOG_POSITION: Array[Vector3] = [
	Vector3(-785, 625, 4527),
	Vector3(-785, 625, 4527),
	Vector3(-1286, 644, 4376),
	Vector3(-1286, 623, 4387),
	Vector3(-1286, 388, 3963),
	Vector3(-1286, 358, 4093),
	Vector3(-1386, 354, 4159),
	Vector3(-1477, 306, 4223),
	Vector3(-1540, 299, 4378),
	Vector3(-1473, 316, 4574),
	Vector3(-1328, 485, 5017),
	Vector3(-1328, 485, 5017),
	Vector3(-1328, 485, 5017),
	Vector3(-1328, 485, 5017),
	Vector3(-1328, 485, 5017)
]

const INTRO_PIPE_TO_DIALOG_FOCUS: Array[Vector3] = [
	Vector3(-1248, 450, 4596),
	Vector3(-1258, 485, 4606),
	Vector3(-1379, 344, 4769),
	Vector3(-1335, 366, 4815),
	Vector3(-1315, 370, 4450),
	Vector3(-1322, 333, 4591),
	Vector3(-1185, 329, 4616),
	Vector3(-1059, 380, 4487),
	Vector3(-1086, 421, 4206),
	Vector3(-1321, 346, 4098),
	Vector3(-1328, 385, 4354),
	Vector3(-1328, 385, 4354),
	Vector3(-1328, 385, 4354),
	Vector3(-1328, 385, 4354),
	Vector3(-1328, 385, 4354)
]

const INTRO_PIPE_TO_DIALOG_FOCUS_SPEED: Array[float] = [
	20.0, 59.0, 59.0, 20.0, 23.0, 40.0, 25.0, 21.0, 14.0, 21.0,
	0.0, 0.0, 0.0, 0.0
]


func _process(delta: float) -> void:
	if not _intro_playing:
		return

	_intro_timer += delta

	# Store the state before we process new logic ticks
	var prev_position := _current_position
	var prev_focus := _current_focus

	# Process fixed 30Hz logic steps
	while _intro_timer >= FRAME_TIME:
		_intro_timer -= FRAME_TIME
		
		# Save the state from the last tick to form the interpolation bounds
		prev_position = _current_position
		prev_focus = _current_focus
		
		_update_intro_frame_forward()
		
		# If the intro finished during this tick, break out
		if not _intro_playing:
			_intro_timer = 0.0
			break

	# Interpolate the actual visual transform based on leftover time
	var alpha: float = clampf(_intro_timer / FRAME_TIME, 0.0, 1.0)
	global_position = prev_position.lerp(_current_position, alpha)
	
	var interpolated_focus := prev_focus.lerp(_current_focus, alpha)
	_set_camera_focus(interpolated_focus)


func play_lakitu_intro() -> void:
	_intro_playing = true
	_intro_timer = 0.0

	_intro_stage = 0
	_intro_frame = 0
	_spline_segment = 0
	_spline_progress = 0.1

	_rebuild_spline_for_current_frame()
	_apply_current_frame()

	# Snap exactly to the first frame without lerping
	global_position = _current_position
	_set_camera_focus(_current_focus)


# ============================================================
# FORWARD PLAYBACK
# ============================================================

func _update_intro_frame_forward() -> void:
	_intro_frame += 1

	if _intro_stage == 0:
		if _intro_frame >= INTRO_FLY_TO_PIPE_END:
			_intro_stage = 1
			_intro_frame = 0
			_spline_segment = 0
			_spline_progress = 0.1

			_apply_pipe_to_dialog_frame()
			return

		_advance_start_to_pipe_spline()
		_apply_start_to_pipe_frame()

	elif _intro_stage == 1:
		if _intro_frame >= INTRO_PIPE_TO_DIALOG_END:
			_intro_playing = false
			_intro_frame = INTRO_PIPE_TO_DIALOG_END - 1
			_apply_pipe_to_dialog_frame() # Apply final position before stopping
			return

		_advance_pipe_to_dialog_spline()
		_apply_pipe_to_dialog_frame()


# ============================================================
# APPLY FRAME (Updates logical target state)
# ============================================================

func _apply_current_frame() -> void:
	if _intro_stage == 0:
		_apply_start_to_pipe_frame()
	else:
		_apply_pipe_to_dialog_frame()


func _apply_start_to_pipe_frame() -> void:
	var position: Vector3 = _evaluate_spline(
		INTRO_START_TO_PIPE_POSITION,
		_spline_segment,
		_spline_progress
	)

	var focus: Vector3 = _evaluate_spline(
		INTRO_START_TO_PIPE_FOCUS,
		_spline_segment,
		_spline_progress
	)

	position.x = -position.x
	position.z = -position.z

	focus.x = -focus.x
	focus.z = -focus.z

	position += Vector3(-1328.0, 260.0, 4664.0)
	focus += Vector3(-1328.0, 260.0, 4664.0)

	# Store target state instead of applying directly
	_current_position = position * SM64_TO_GODOT
	_current_focus = focus * SM64_TO_GODOT


func _apply_pipe_to_dialog_frame() -> void:
	var position: Vector3 = _evaluate_spline(
		INTRO_PIPE_TO_DIALOG_POSITION,
		_spline_segment,
		_spline_progress
	)

	var focus: Vector3 = _evaluate_spline(
		INTRO_PIPE_TO_DIALOG_FOCUS,
		_spline_segment,
		_spline_progress
	)

	_current_position = position * SM64_TO_GODOT
	_current_focus = focus * SM64_TO_GODOT


# ============================================================
# SPLINE
# ============================================================

func _evaluate_spline(
	points: Array[Vector3],
	segment: int,
	progress: float
) -> Vector3:
	var max_segment: int = points.size() - 4

	if max_segment < 0:
		return Vector3.ZERO

	segment = clampi(segment, 0, max_segment)

	var p0: Vector3 = points[segment]
	var p1: Vector3 = points[segment + 1]
	var p2: Vector3 = points[segment + 2]
	var p3: Vector3 = points[segment + 3]

	var t: float = clampf(progress, 0.0, 1.0)

	var t2: float = t * t
	var t3: float = t2 * t

	var weight0: float = -0.5 * t3 + t2 - 0.5 * t
	var weight1: float = 1.5 * t3 - 2.5 * t2 + 1.0
	var weight2: float = -1.5 * t3 + 2.0 * t2 + 0.5 * t
	var weight3: float = 0.5 * t3 - 0.5 * t2

	return (
		p0 * weight0
		+ p1 * weight1
		+ p2 * weight2
		+ p3 * weight3
	)


# ============================================================
# REBUILD SPLINE
# ============================================================

func _rebuild_spline_for_current_frame() -> void:
	_spline_segment = 0
	_spline_progress = 0.1

	if _intro_stage == 0:
		for i in range(_intro_frame):
			_advance_start_to_pipe_spline()

	elif _intro_stage == 1:
		for i in range(_intro_frame):
			_advance_pipe_to_dialog_spline()


# ============================================================
# SPLINE PROGRESS
# ============================================================

func _advance_start_to_pipe_spline() -> void:
	if _spline_segment >= INTRO_START_TO_PIPE_FOCUS_SPEED.size():
		return

	var speed: float = INTRO_START_TO_PIPE_FOCUS_SPEED[_spline_segment]

	if speed <= 0.0:
		return

	_spline_progress += 1.0 / speed

	while _spline_progress >= 1.0:
		_spline_progress -= 1.0
		_spline_segment += 1

		if _spline_segment >= INTRO_START_TO_PIPE_FOCUS_SPEED.size():
			_spline_segment = INTRO_START_TO_PIPE_FOCUS_SPEED.size() - 1
			_spline_progress = 1.0
			return


func _advance_pipe_to_dialog_spline() -> void:
	if _spline_segment >= INTRO_PIPE_TO_DIALOG_FOCUS_SPEED.size():
		return

	var speed: float = INTRO_PIPE_TO_DIALOG_FOCUS_SPEED[_spline_segment]

	if speed <= 0.0:
		return

	_spline_progress += 1.0 / speed

	while _spline_progress >= 1.0:
		_spline_progress -= 1.0
		_spline_segment += 1

		if _spline_segment >= INTRO_PIPE_TO_DIALOG_FOCUS_SPEED.size():
			_spline_segment = INTRO_PIPE_TO_DIALOG_FOCUS_SPEED.size() - 1
			_spline_progress = 1.0
			return


# ============================================================
# CAMERA ROTATION
# ============================================================

func _set_camera_focus(focus: Vector3) -> void:
	var direction: Vector3 = focus - global_position

	if direction.length_squared() <= 0.000001:
		return

	look_at(focus, Vector3.UP)

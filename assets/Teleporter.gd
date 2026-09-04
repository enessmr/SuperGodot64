@icon("res://addons/libsm64_godot/libsm64_mario/libsm64_mario_tp.svg")
class_name Teleporter
extends MeshInstance3D

@export var WARP_NODE_B: Marker3D
@export var destination_teleporter: Teleporter
@export var warp_radius := 2.0
@export var fade_duration := 0.5
@export var fade_wait := 0.2
@export var duration_to_white_screen_effect := 0.3
@export var duration_to_stay_in_white_screen := 0.7

var _used := false
var _waiting_for_landing := false
var _teleport_lock := false
var _left_idle_after_teleport := false
var _previous_action: int = -1

@onready var _mario: LibSM64Mario = null
@onready var ws: ColorRect = $TeleporterCVLayer/ColorRect


func _ready() -> void:
	_mario = get_parent().get_node_or_null(
		"FinalLibSM64MarioLoc"
	) as LibSM64Mario

	if not _mario:
		_mario = get_parent().get_node_or_null(
			"LibSM64Mario"
		) as LibSM64Mario

	if _mario:
		_previous_action = _mario.action

	ws.color.a = 0.0
	ws.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _physics_process(_delta: float) -> void:
	if not _mario:
		_mario = get_parent().get_node_or_null(
			"FinalLibSM64MarioLoc"
		) as LibSM64Mario

		if not _mario:
			_mario = get_parent().get_node_or_null(
				"LibSM64Mario"
			) as LibSM64Mario

		if not _mario:
			return

		_previous_action = _mario.action

	if _teleport_lock:
		var current_action: int = _mario.action

		var is_teleport_action: bool = (
			current_action == LibSM64.ACT_TELEPORT_FADE_OUT
			or current_action == LibSM64.ACT_TELEPORT_FADE_IN
		)

		if not is_teleport_action:
			if (
				_previous_action == LibSM64.ACT_IDLE
				and current_action != LibSM64.ACT_IDLE
			):
				_left_idle_after_teleport = true

			if (
				_left_idle_after_teleport
				and _previous_action != LibSM64.ACT_IDLE
				and current_action == LibSM64.ACT_IDLE
			):
				_teleport_lock = false
				_left_idle_after_teleport = false

		_previous_action = current_action
		_waiting_for_landing = false
		return

	var distance: float = global_position.distance_to(
		_mario.global_position
	)

	if distance > warp_radius:
		_waiting_for_landing = false
		_previous_action = _mario.action
		return

	_waiting_for_landing = true

	if (
		_mario.action != LibSM64.ACT_IDLE
		and _mario.action != LibSM64.ACT_CROUCHING
		and _mario.action != LibSM64.ACT_PANTING
	):
		_previous_action = _mario.action
		return

	_waiting_for_landing = false

	_teleport()

	_previous_action = _mario.action


func _teleport() -> void:
	if _used:
		return

	if not WARP_NODE_B:
		push_warning("Teleporter: WARP_NODE_B is not assigned.")
		return

	_used = true

	_teleport_lock = true
	_left_idle_after_teleport = false

	var dest_teleporter: Teleporter = destination_teleporter

	if not dest_teleporter:
		var closest_dist: float = INF
		var stack = [get_tree().root]

		while not stack.is_empty():
			var node = stack.pop_back()

			if node is Teleporter and node != self:
				var d: float = node.global_position.distance_to(
					WARP_NODE_B.global_position
				)

				if d < closest_dist:
					closest_dist = d
					dest_teleporter = node

			for child in node.get_children():
				stack.append(child)

	if dest_teleporter:
		dest_teleporter._teleport_lock = true
		dest_teleporter._left_idle_after_teleport = false
		dest_teleporter._waiting_for_landing = false
	else:
		push_warning(
			"Teleporter: Could not find destination Teleporter near WARP_NODE_B! Assign it in the inspector."
		)

	_mario.velocity = Vector3.ZERO
	_mario.action = LibSM64.ACT_TELEPORT_FADE_OUT

	await _fade_out()

	await get_tree().create_timer(
		duration_to_white_screen_effect
	).timeout

	await _fade_in_ws()

	await get_tree().create_timer(
		duration_to_stay_in_white_screen
	).timeout

	_mario.teleport(WARP_NODE_B.global_position)

	_mario.set_angle(
		WARP_NODE_B.global_transform.basis.get_rotation_quaternion()
	)

	_mario.velocity = Vector3.ZERO
	_mario.action = LibSM64.ACT_TELEPORT_FADE_IN

	await _fade_out_ws()

	await _fade_in()

	_mario.alpha_set(1.0)
	_mario.alpha_reset()

	await get_tree().create_timer(
		fade_wait + 0.3
	).timeout

	_used = false


func _fade_out() -> void:
	var tween := create_tween()

	tween.tween_method(
		_set_mario_alpha,
		1.0,
		0.0,
		fade_duration
	)

	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()

	tween.tween_method(
		_set_mario_alpha,
		0.0,
		1.0,
		fade_duration
	)

	await tween.finished


func _fade_out_ws() -> void:
	var tween := create_tween()

	tween.tween_method(
		_set_ws_alpha,
		1.0,
		0.0,
		fade_duration
	)

	await tween.finished


func _fade_in_ws() -> void:
	var tween := create_tween()

	tween.tween_method(
		_set_ws_alpha,
		0.0,
		1.0,
		fade_duration
	)

	await tween.finished


func _set_mario_alpha(alpha: float) -> void:
	_mario.alpha_set(alpha)


func _set_ws_alpha(alpha: float) -> void:
	ws.color.a = alpha

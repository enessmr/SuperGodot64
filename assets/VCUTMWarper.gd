@icon("res://addons/libsm64_godot/libsm64_mario/libsm64_mario_tp.svg")
class_name VCUTMWarper
extends MeshInstance3D

@export var WARP_NODE_B: PackedScene
@export var scene_warp: bool = false
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
	_mario = _find_mario()

	if _mario:
		_previous_action = _mario.action

	if ws:
		ws.color.a = 0.0
		ws.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _physics_process(_delta: float) -> void:
	if not _mario or not is_instance_valid(_mario):
		_mario = _find_mario()

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

	# ============================================================
	# SCENE WARP
	# ============================================================

	if scene_warp:
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

		# WARP_NODE_B is the destination scene.
		var result := get_tree().change_scene_to_packed(WARP_NODE_B)

		if result != OK:
			push_warning(
				"Teleporter: Could not change to destination scene."
			)

			await _fade_out_ws()
			_used = false
			_teleport_lock = false
			return

		# Wait for the new scene to actually exist.
		await get_tree().process_frame
		await get_tree().process_frame

		var new_mario: LibSM64Mario = _find_mario()

		if not new_mario:
			push_warning(
				"Teleporter: Destination scene loaded, but LibSM64Mario could not be found."
			)

			await _fade_out_ws()
			return

		_mario = new_mario

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
		return

	# ============================================================
	# NORMAL WARP
	# ============================================================

	var dest_teleporter: Teleporter = destination_teleporter

	if not dest_teleporter:
		var closest_dist: float = INF
		var stack = [get_tree().root]

		while not stack.is_empty():
			var node = stack.pop_back()

			if node is Teleporter and node != self:
				var d: float = node.global_position.distance_to(
					_get_scene_warp_position()
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
			"Teleporter: Could not find destination Teleporter! Assign it in the inspector."
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

	var destination_node := _get_destination_node()

	if destination_node:
		_mario.teleport(destination_node.global_position)

		_mario.set_angle(
			destination_node.global_transform.basis.get_rotation_quaternion()
		)
	else:
		push_warning(
			"Teleporter: Could not find destination node."
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


func _find_mario() -> LibSM64Mario:
	var root := get_tree().current_scene

	if not root:
		return null

	var stack = [root]

	while not stack.is_empty():
		var node = stack.pop_back()

		if node is LibSM64Mario:
			return node as LibSM64Mario

		for child in node.get_children():
			stack.append(child)

	return null


func _get_destination_node() -> Node3D:
	if not WARP_NODE_B:
		return null

	# WARP_NODE_B is normally a node in the current scene for
	# normal warps. This function exists so the destination lookup
	# stays separate from the scene-warp behavior.
	return null


func _get_scene_warp_position() -> Vector3:
	if not WARP_NODE_B:
		return global_position

	return global_position


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
	if _mario and is_instance_valid(_mario):
		_mario.alpha_set(alpha)


func _set_ws_alpha(alpha: float) -> void:
	ws.color.a = alpha

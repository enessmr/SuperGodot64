@icon("res://addons/libsm64_godot/libsm64_mario/libsm64_mario_tp.svg")
class_name Teleporter
extends MeshInstance3D

@export var WARP_NODE_B: Marker3D
@export var warp_radius := 2.0
@export var fade_duration := 0.5
@export var fade_wait := 0.2
@export var duration_to_white_screen_effect := 0.3
@export var duration_to_stay_in_white_screen := 0.7

var _used := false
var _waiting_for_landing := false
var _was_vanish_cap := false

@onready var _mario: LibSM64Mario = null
@onready var _teleport_sfx: LibSM64AudioStreamPlayer = %LibSM64AudioStreamPlayer
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
		_was_vanish_cap = _mario.vanish_cap

	ws.color.a = 0.0
	ws.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _physics_process(_delta: float) -> void:
	if _used:
		return

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
			
		_was_vanish_cap = _mario.vanish_cap

	# Detect if the vanish cap just ran out
	if _was_vanish_cap and not _mario.vanish_cap:
		_mario.alpha_set(1.0)
		
	# Update the vanish cap state tracker
	_was_vanish_cap = _mario.vanish_cap

	var distance := global_transform.origin.distance_to(
		_mario.global_transform.origin
	)

	if distance <= warp_radius:
		_waiting_for_landing = true
	elif _waiting_for_landing:
		_waiting_for_landing = false
		return

	if not _waiting_for_landing:
		return

	if (
		_mario.action != LibSM64.ACT_IDLE
		and _mario.action != LibSM64.ACT_PANTING
	):
		return

	_waiting_for_landing = false
	_teleport()


func _teleport() -> void:
	if _used:
		return

	if not WARP_NODE_B:
		push_warning("Teleporter: WARP_NODE_B is not assigned.")
		return

	_used = true

	_mario.velocity = Vector3.ZERO
	_mario.action = LibSM64.ACT_IDLE

	LibSM64.play_sound(
		LibSM64.SoundBits.SOUND_ACTION_TELEPORT,
		_mario.global_position
	)

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

	await get_tree().create_timer(
		fade_wait + 0.3
	).timeout

	_mario.action = LibSM64.ACT_IDLE
	_used = false


func _fade_out() -> void:
	var starting_alpha := 0.5 if _mario.vanish_cap else 1.0

	var tween := create_tween()

	tween.tween_method(
		_set_mario_alpha,
		starting_alpha,
		0.0,
		fade_duration
	)

	await tween.finished


func _fade_in() -> void:
	var ending_alpha := 0.5 if _mario.vanish_cap else 1.0

	var tween := create_tween()

	tween.tween_method(
		_set_mario_alpha,
		0.0,
		ending_alpha,
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

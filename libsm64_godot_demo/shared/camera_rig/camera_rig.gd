extends Node3D


const ANGLE_X_MIN := -PI / 4
const ANGLE_X_MAX := PI / 3

@export var is_y_inverted := false
@export var deadzone := PI / 10
@export var sensitivity_gamepad := Vector2(2.5, 2.5)
@export var sensitivity_mouse := Vector2(0.1, 0.1)

@onready var player := get_parent() as LibSM64Mario

var _input_relative := Vector2.ZERO
var _locked : bool = false
signal lock
signal unlock

func set_locked(value: bool) -> void:
	if _locked == value:
		return

	_locked = value

	if _locked:
		lock.emit()
	else:
		unlock.emit()

func unlock_rig() -> void:
	if not _locked:
		return

	_locked = false
	unlock.emit()

func _process(delta: float) -> void:
	if not player:
		return

	if player.play_mode != LibSM64Mario.PlayMode.NORMAL:
		_input_relative = Vector2.ZERO
		return

	global_transform.origin = player.global_transform.origin

	var look_direction := get_look_direction()
	var _move_direction := get_move_direction()

	if _locked:
		return

	if _input_relative.length() > 0:
		update_rotation(_input_relative * sensitivity_mouse * delta)
		_input_relative = Vector2.ZERO
	elif look_direction.length() > 0:
		update_rotation(look_direction * sensitivity_gamepad * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_input_relative = Vector2.ZERO
		return

	var mouse_event := event as InputEventMouseMotion

	if mouse_event and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_input_relative += mouse_event.relative


func update_rotation(offset: Vector2) -> void:
	# Yaw is intentionally NOT wrapped.
	# This allows the camera to pass through 180 degrees
	# without jumping from PI to -PI.
	rotation.y -= offset.x

	if is_y_inverted:
		rotation.x -= offset.y
	else:
		rotation.x += offset.y

	rotation.x = clamp(rotation.x, ANGLE_X_MIN, ANGLE_X_MAX)

	# Keep roll disabled.
	rotation.z = 0.0


# Returns the direction of the camera movement from the player
func get_look_direction() -> Vector2:
	return Vector2(
		Input.get_axis("camera_right", "camera_left"),
		Input.get_axis("camera_up", "camera_down")
	).normalized()


# Returns the move direction of the character controlled by the player
func get_move_direction() -> Vector3:
	return Vector3(
		Input.get_axis(
			"libsm64_mario_inputs_stick_right",
			"libsm64_mario_inputs_stick_left"
		),
		0,
		Input.get_axis(
			"libsm64_mario_inputs_stick_down",
			"libsm64_mario_inputs_stick_up"
		)
	)

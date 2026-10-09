@icon("res://models/TREE_ICON.svg")
class_name SM64TreeSafe
extends MeshInstance3D

@export_range(0.1, 3.0, 0.05) var hitbox_radius: float = 0.8
@export_range(1.0, 20.0, 0.1) var hitbox_height: float = 5.0
@export_range(0.0, 2.0, 0.05) var grab_height_offset: float = 0.65
@export_range(0.2, 4.0, 0.05) var grab_radius: float = 1.7
@export_range(0.5, 8.0, 0.1) var climb_speed: float = 2.8
@export_range(1.0, 20.0, 0.5) var attach_speed: float = 10.0
@export_range(2.0, 12.0, 0.1) var dismount_speed: float = 6.0
@export var interpolate: bool = true

const ACTION_IDLE: int = LibSM64.ACT_IDLE
const ACTION_JUMP: int = LibSM64.ACT_JUMP

var _mario: LibSM64Mario = null
var _latched: bool = false
var _grab_cooldown: float = 0.0
var _held_height: float = 0.0
var _tree_base: Vector3 = Vector3.ZERO
var _tree_axis: Vector3 = Vector3.UP
var _radial_axis: Vector3 = Vector3.FORWARD

func _apply_interpolation_setting() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)


func _ready() -> void:
	_apply_interpolation_setting()
	reset_physics_interpolation()
	_mario = _find_mario()
	_refresh_tree_frame()

func _physics_process(delta: float) -> void:
	_apply_interpolation_setting()
	_grab_cooldown = maxf(0.0, _grab_cooldown - delta)
	_refresh_tree_frame()
	if not is_instance_valid(_mario):
		_mario = _find_mario()
		if not is_instance_valid(_mario):
			return
	if _latched:
		_process_climbing(delta)
	else:
		_try_grab()

func _find_mario() -> LibSM64Mario:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("LibSM64Mario", true, false) as LibSM64Mario

func _refresh_tree_frame() -> void:
	_tree_base = global_position
	_tree_axis = global_basis.y.normalized()
	if _tree_axis.length_squared() < 0.9:
		_tree_axis = Vector3.UP

func _try_grab() -> void:
	if _grab_cooldown > 0.0 or _mario.id < 0 or _mario.is_collecting_star():
		return
	var action: int = _mario.action
	if not _is_grabbable_action(action):
		return
	var relative: Vector3 = _mario.global_position - _tree_base
	var height: float = relative.dot(_tree_axis)
	if height < -0.1 or height > hitbox_height + 0.35:
		return
	var radial: Vector3 = relative - _tree_axis * height
	if radial.length() > grab_radius:
		return
	if not _is_airborne_action(action) and _mario.velocity.dot(_tree_axis) <= 1.0:
		return
	_radial_axis = radial.normalized() if radial.length_squared() > 0.0001 else Vector3.FORWARD
	_latched = true
	_held_height = clampf(height + grab_height_offset, grab_height_offset, hitbox_height)
	_mario.velocity = Vector3.ZERO
	_mario.forward_velocity = 0.0
	_mario.face_angle = atan2(-_radial_axis.x, -_radial_axis.z)
	_mario.teleport(_position_on_trunk(_held_height))
	# Leave LibSM64's action untouched: setting pole actions directly crashes
	# because native interact_pole state is unavailable in this binding.
	_mario.anim_id = LibSM64.MarioAnimID.MARIO_ANIM_GRAB_POLE_SHORT
	_mario.anim_frame = 0
	_mario.reset_interpolation()

func _process_climbing(delta: float) -> void:
	if _mario.id < 0:
		_latched = false
		return
	if Input.is_action_just_pressed(_mario.mario_inputs_button_a) or Input.is_action_just_pressed(_mario.mario_inputs_button_b):
		_jump_off_trunk()
		return
	var stick: Vector2 = Input.get_vector(_mario.mario_inputs_stick_left, _mario.mario_inputs_stick_right, _mario.mario_inputs_stick_up, _mario.mario_inputs_stick_down)
	var climb_input: float = -stick.y
	if absf(climb_input) < 0.15:
		climb_input = 0.0
	_held_height = clampf(_held_height + climb_input * climb_speed * delta, grab_height_offset, hitbox_height)
	if absf(stick.x) > 0.15:
		_radial_axis = _radial_axis.rotated(_tree_axis, stick.x * delta * 1.5).normalized()
	var target_position: Vector3 = _position_on_trunk(_held_height)
	var blend: float = 1.0 - exp(-attach_speed * delta)
	_mario.teleport(_mario.global_position.lerp(target_position, blend))
	_mario.velocity = Vector3.ZERO
	_mario.forward_velocity = 0.0
	_mario.face_angle = atan2(-_radial_axis.x, -_radial_axis.z)
	var animation: LibSM64.MarioAnimID = LibSM64.MarioAnimID.MARIO_ANIM_IDLE_ON_POLE
	if _held_height < hitbox_height - 0.08:
		animation = LibSM64.MarioAnimID.MARIO_ANIM_CLIMB_UP_POLE
	_mario.anim_id = animation

func _position_on_trunk(height: float) -> Vector3:
	return _tree_base + _tree_axis * height + _radial_axis * (hitbox_radius + 0.22)

func _jump_off_trunk() -> void:
	_latched = false
	_grab_cooldown = 0.45
	_mario.teleport(_position_on_trunk(_held_height))
	_mario.velocity = _radial_axis * dismount_speed + _tree_axis * (dismount_speed * 0.72)
	_mario.forward_velocity = dismount_speed
	_mario.face_angle = atan2(-_radial_axis.x, -_radial_axis.z)
	_mario.action = ACTION_JUMP
	_mario.reset_interpolation()

func _is_grabbable_action(action: int) -> bool:
	return _is_airborne_action(action) or action == ACTION_IDLE or action == LibSM64.ACT_WALKING or action == LibSM64.ACT_BRAKING

func _is_airborne_action(action: int) -> bool:
	return action == ACTION_JUMP or action == LibSM64.ACT_DOUBLE_JUMP or action == LibSM64.ACT_TRIPLE_JUMP or action == LibSM64.ACT_BACKFLIP or action == LibSM64.ACT_SIDE_FLIP or action == LibSM64.ACT_FREEFALL

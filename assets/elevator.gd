extends AnimatableBody3D

## SM64 Bob-omb Battlefield checkerboard platform cycle.
##
## BOB parameters:
##   BPARAM1 = 0
##   BPARAM2 = 40
##
## This script controls one platform.
## Create two instances with opposite starting states.

const SM64_TICK_RATE: float = 60.0
const SM64_MOVE_SPEED: float = 10.0
const SM64_ROTATION_SPEED: float = 512.0
const SM64_HALF_TURN: float = 32768.0

# BOB uses BPARAM2(40)
@export var movement_ticks: int = 40
@export var interpolate: bool = true

@export_range(0, 1, 1) var starting_phase: int = 0

var _base_position: Vector3 = Vector3.ZERO
var _tick_accumulator: float = 0.0
var _elapsed_ticks: int = 0


# SM64 oAction
var action: int = 0

# Equivalent to oTimer
var action_time: float = 0.0

# Equivalent to oMoveAnglePitch
var move_angle_pitch: float = 0.0

# Equivalent to oFaceAnglePitch
var face_angle_pitch: float = 0.0

# Equivalent to oAngleVelPitch
var angle_vel_pitch: float = 0.0

# Equivalent to oVelY
var vel_y: float = 0.0

# Equivalent to oForwardVel
var forward_vel: float = 0.0

# Equivalent to oCheckerBoardPlatformUnkF8
var transition_action: int = 0

# Seconds per SM64 frame
var sm64_tick: float = 1.0 / SM64_TICK_RATE

# Accumulator used to preserve SM64-style timing while still using delta.
var tick_accumulator: float = 0.0


func _apply_interpolation_setting() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)


func _ready() -> void:
	_apply_interpolation_setting()
	_base_position = global_position
	_elapsed_ticks = 0 if starting_phase == 0 else _cycle_length() / 2
	_update_transform()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_apply_interpolation_setting()
	_tick_accumulator += delta * SM64_TICK_RATE
	while _tick_accumulator >= 1.0:
		_tick_accumulator -= 1.0
		_elapsed_ticks += 1
		_update_transform()


func _cycle_length() -> int:
	var rise_ticks: int = max(movement_ticks, 1)
	var rotation_ticks: int = int(SM64_HALF_TURN / SM64_ROTATION_SPEED)
	return 2 * (rise_ticks + rotation_ticks)


func _update_transform() -> void:
	var rise_ticks: int = max(movement_ticks, 1)
	var rotation_ticks: int = int(SM64_HALF_TURN / SM64_ROTATION_SPEED)
	var phase_tick: int = posmod(_elapsed_ticks, _cycle_length())
	var lower_rotation_start: int = rise_ticks
	var upward_start: int = rise_ticks + rotation_ticks
	var upper_rotation_start: int = upward_start + rise_ticks
	var height: float = 0.0
	var pitch_angle: float = 0.0

	if phase_tick < lower_rotation_start:
		height = -SM64_MOVE_SPEED * float(phase_tick)
	elif phase_tick < upward_start:
		height = -SM64_MOVE_SPEED * float(rise_ticks)
		pitch_angle = float(phase_tick - lower_rotation_start) * SM64_ROTATION_SPEED
	elif phase_tick < upper_rotation_start:
		height = -SM64_MOVE_SPEED * float(rise_ticks) + SM64_MOVE_SPEED * float(phase_tick - upward_start)
		pitch_angle = SM64_HALF_TURN
	else:
		pitch_angle = SM64_HALF_TURN + float(phase_tick - upper_rotation_start) * SM64_ROTATION_SPEED

	global_position = _base_position + Vector3(0.0, height, 0.0)
	rotation.x = pitch_angle * TAU / 65536.0


func _sm64_tick() -> void:
	return

func _unused_sm64_tick() -> void:
	return
	transition_action = 0

	match action:
		0:
			# Original:
			#
			# if (o->oBhvParams2ndByte == 0)
			#     o->oAction = 1;
			# else
			#     o->oAction = 3;
			#
			# BOB uses 40, so this goes to action 3.
			if movement_ticks == 0:
				action = 1
			else:
				action = 3

			action_time = 0.0

		1:
			# checkerboard_plat_act_move_y(2, 10.0f, timer)
			_act_move_y(2, 10.0)

		2:
			# checkerboard_plat_act_rotate(3, 512)
			_act_rotate(3, 512)

		3:
			# checkerboard_plat_act_move_y(4, -10.0f, timer)
			_act_move_y(4, -10.0)

		4:
			# checkerboard_plat_act_rotate(1, -512)
			_act_rotate(1, -512)

	# Original:
	#
	# o->oMoveAnglePitch += absi(o->oAngleVelPitch);
	# o->oFaceAnglePitch += absi(o->oAngleVelPitch);
	# o->oFaceAngleYaw = o->oMoveAngleYaw;
	#
	# We use the absolute value because the original SM64 code
	# advances the pitch angle positively while the sign of
	# angle_vel_pitch determines the direction of travel.
	var abs_angle_velocity: float = abs(angle_vel_pitch)

	move_angle_pitch += abs_angle_velocity
	face_angle_pitch += abs_angle_velocity

	# Keep the angle inside one full turn.
	move_angle_pitch = fmod(move_angle_pitch, 65536.0)
	face_angle_pitch = fmod(face_angle_pitch, 65536.0)

	# Original:
	#
	# if (o->oMoveAnglePitch != 0) {
	#     o->oForwardVel =
	#         signum_positive(o->oAngleVelPitch)
	#         * sins(o->oMoveAnglePitch)
	#         * sp24;
	#
	#     o->oVelY =
	#         signum_positive(o->oAngleVelPitch)
	#         * coss(o->oMoveAnglePitch)
	#         * sp24;
	# }
	#
	# Godot's sin/cos use radians, so convert the SM64 angle.
	if move_angle_pitch != 0.0:
		var radians: float = _sm64_angle_to_radians(move_angle_pitch)

		var direction: float = 1.0

		if angle_vel_pitch < 0.0:
			direction = -1.0

		forward_vel = 0.0
		vel_y = 0.0
	else:
		forward_vel = 0.0
		vel_y = 0.0

	# Original:
	#
	# if (o->oCheckerBoardPlatformUnkF8 == 1) {
	#     o->oAngleVelPitch = 0;
	#     o->oFaceAnglePitch &= ~0x7FFF;
	#     cur_obj_move_using_fvel_and_gravity();
	# } else {
	#     cur_obj_move_using_fvel_and_gravity();
	# }
	#
	# We reproduce the special transition behavior.
	if transition_action == 1:
		angle_vel_pitch = 0.0

		# Clear the lower 15 bits, matching:
		# o->oFaceAnglePitch &= ~0x7FFF;
		face_angle_pitch = float(int(face_angle_pitch) & ~0x7FFF)

	# Move using the calculated velocity.
	_move_platform()

	# Advance the timer after the behavior tick.
	action_time += 1.0

	# If the action changed this tick, reset its timer.
	#
	# This corresponds to SM64's oTimer being reset when the
	# action changes.
	if transition_action != 0:
		action_time = 0.0


func _act_move_y(next_action: int, velocity: float) -> void:
	# Original:
	#
	# o->oMoveAnglePitch = 0;
	# o->oAngleVelPitch = 0;
	# o->oForwardVel = 0.0f;
	# o->oVelY = vel;
	#
	# Reset rotation while moving vertically.
	move_angle_pitch = 0.0
	angle_vel_pitch = 0.0
	forward_vel = 0.0
	vel_y = velocity

	# Original:
	#
	# if (o->oTimer > a2)
	#     o->oAction++;
	#
	# movement_ticks is BPARAM2.
	if action_time > float(movement_ticks):
		action = next_action
		transition_action = next_action
		action_time = 0.0


func _act_rotate(next_action: int, angular_velocity: int) -> void:
	# Original:
	#
	# o->oVelY = 0.0f;
	# o->oAngleVelPitch = a1;
	#
	vel_y = 0.0
	angle_vel_pitch = float(angular_velocity)

	# Original:
	#
	# if (o->oTimer + 1 == 0x8000 / absi(a1))
	#     o->oAction = a0;
	#
	# 0x8000 / 512 = 64 ticks.
	#
	# This means the original behavior waits 64 SM64 ticks
	# for the half-turn threshold used by this state.
	var rotation_ticks: int = int(SM64_HALF_TURN / abs(float(angular_velocity)))

	if int(action_time) + 1 == rotation_ticks:
		action = next_action
		transition_action = next_action
		action_time = 0.0

	# Original:
	# o->oCheckerBoardPlatformUnkF8 = a0;
	transition_action = next_action


func _move_platform() -> void:
	# Convert SM64 "per frame" velocity to actual movement
	# during this 1/60 second simulation tick.
	#
	# Because _sm64_tick() itself is fixed at 60 Hz, these
	# values are already one SM64 tick of movement.
	var movement := Vector3(
		forward_vel,
		vel_y,
		0.0
	)

	# The original platform's forward direction follows yaw.
	# For the default BOB orientation yaw is zero, so the
	# forward velocity corresponds to local +X.
	movement = movement.rotated(Vector3.UP, rotation.y)

	global_position += movement

	# Apply the pitch rotation represented by the SM64 angle.
	rotation.x = _sm64_angle_to_radians(face_angle_pitch)


func _apply_transform() -> void:
	rotation.x = _sm64_angle_to_radians(face_angle_pitch)


func _sm64_angle_to_radians(angle: float) -> float:
	# SM64 uses a 16-bit angle:
	#
	# 0x0000 = 0°
	# 0x4000 = 90°
	# 0x8000 = 180°
	# 0xC000 = 270°
	# 0x10000 = 360°
	#
	return angle * TAU / 65536.0

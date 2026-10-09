extends AnimatableBody3D

## SM64 checkerboard platform behavior.
## Based directly on:
## src/game/behaviors/checkerboard_platform.inc.c

const SM64_TICK_RATE: float = 60.0
const SM64_TICK: float = 1.0 / SM64_TICK_RATE

# Original SM64 values.
const MOVE_SPEED: float = 10.0
const ROTATION_SPEED: float = 512.0
const SM64_FULL_TURN: float = 65536.0
const SM64_HALF_TURN: float = 32768.0

# BOB uses BPARAM2(40).
@export var movement_ticks: int = 40
@export var interpolate: bool = true

# 0 = the platform starts in action 1.
# 1 = the platform starts in action 3.
@export_range(0, 1, 1) var starting_phase: int = 0

# Original D_8032F754[0].unk2 for BOB.
@export var arc_radius: float = 7.0

# Godot scale conversion.
# Change this if your SM64 -> Godot scale is different.
@export var sm64_scale: float = 0.01


# Equivalent to oAction.
var _action: int = 0

# Equivalent to oTimer.
var _timer: int = 0

# Equivalent to oMoveAnglePitch.
var _move_angle_pitch: float = 0.0

# Equivalent to oFaceAnglePitch.
var _face_angle_pitch: float = 0.0

# Equivalent to oAngleVelPitch.
var _angle_vel_pitch: float = 0.0

# Equivalent to oVelY.
var _vel_y: float = 0.0

# Equivalent to oForwardVel.
var _forward_vel: float = 0.0

# Equivalent to oCheckerBoardPlatformUnkF8.
var _transition_action: int = 0

var _tick_accumulator: float = 0.0


func _apply_interpolation_setting() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)


func _ready() -> void:
	_apply_interpolation_setting()
	# Equivalent to the action selected by bhv_checkerboard_platform_loop().
	if starting_phase == 0:
		_action = 1
	else:
		_action = 3
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_apply_interpolation_setting()
	_tick_accumulator += delta

	while _tick_accumulator >= SM64_TICK:
		_tick_accumulator -= SM64_TICK
		_sm64_update()


func _sm64_update() -> void:
	_transition_action = 0

	match _action:
		0:
			# Original:
			#
			# if (o->oBhvParams2ndByte == 0)
			#     o->oAction = 1;
			# else
			#     o->oAction = 3;
			#
			# BOB has BPARAM2 = 40.
			_action = 3

		1:
			_checkerboard_plat_act_move_y(
				2,
				10.0
			)

		2:
			_checkerboard_plat_act_rotate(
				3,
				512
			)

		3:
			_checkerboard_plat_act_move_y(
				4,
				-10.0
			)

		4:
			_checkerboard_plat_act_rotate(
				1,
				-512
			)

	# Original:
	#
	# o->oMoveAnglePitch += absi(o->oAngleVelPitch);
	# o->oFaceAnglePitch += absi(o->oAngleVelPitch);

	var angle_step: float = abs(_angle_vel_pitch)

	_move_angle_pitch += angle_step
	_face_angle_pitch += angle_step

	_move_angle_pitch = fmod(
		_move_angle_pitch,
		SM64_FULL_TURN
	)

	_face_angle_pitch = fmod(
		_face_angle_pitch,
		SM64_FULL_TURN
	)

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

	if _move_angle_pitch != 0.0:
		var angle: float = _sm64_to_radians(_move_angle_pitch)

		var direction: float = 1.0

		if _angle_vel_pitch < 0.0:
			direction = -1.0

		_forward_vel = (
			direction
			* sin(angle)
			* arc_radius
		)

		_vel_y = (
			direction
			* cos(angle)
			* arc_radius
		)
	else:
		_forward_vel = 0.0
		_vel_y = 0.0

	# Original special transition handling.
	if _transition_action == 1:
		_angle_vel_pitch = 0.0

		# o->oFaceAnglePitch &= ~0x7FFF;
		_face_angle_pitch = float(
			int(_face_angle_pitch) & ~0x7FFF
		)

	_move_using_fvel()

	_timer += 1


func _checkerboard_plat_act_move_y(
	next_action: int,
	velocity: float
) -> void:
	# Exact behavior from the decomp.

	_move_angle_pitch = 0.0
	_angle_vel_pitch = 0.0
	_forward_vel = 0.0
	_vel_y = velocity

	if _timer > movement_ticks:
		_action = next_action
		_transition_action = next_action
		_timer = 0


func _checkerboard_plat_act_rotate(
	next_action: int,
	angular_velocity: int
) -> void:
	_vel_y = 0.0
	_angle_vel_pitch = float(angular_velocity)

	var rotation_ticks: int = int(
		SM64_HALF_TURN / abs(float(angular_velocity))
	)

	if _timer + 1 == rotation_ticks:
		_action = next_action
		_transition_action = next_action
		_timer = 0

	# Exact:
	# o->oCheckerBoardPlatformUnkF8 = a0;
	_transition_action = next_action


func _move_using_fvel() -> void:
	# SM64 face pitch -> Godot radians.
	rotation.x = _sm64_to_radians(_face_angle_pitch)


func _sm64_to_radians(angle: float) -> float:
	return angle * TAU / SM64_FULL_TURN

extends RigidBody3D

@export var spring_strength: float = 20.0
@export var damping: float = 5.0

# Maximum tilt in radians.
@export var max_tilt: float = 0.6

var rest_rotation: Basis


func _ready() -> void:
	# Remember the platform's starting orientation.
	rest_rotation = global_transform.basis
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(-0.003, -0.025, -0.001)

func _physics_process(_delta: float) -> void:
	# Get the platform's current rotation relative to its starting rotation.
	var relative_basis := rest_rotation.inverse() * global_transform.basis

	var relative_rotation := relative_basis.get_euler()

	# X-axis restoring torque.
	var x_angle := wrapf(relative_rotation.x, -PI, PI)
	var x_angular_velocity := angular_velocity.x

	var x_torque := -x_angle * spring_strength
	x_torque -= x_angular_velocity * damping

	# Z-axis restoring torque.
	var z_angle := wrapf(relative_rotation.z, -PI, PI)
	var z_angular_velocity := angular_velocity.z

	var z_torque := -z_angle * spring_strength
	z_torque -= z_angular_velocity * damping

	# Apply both restoring torques.
	apply_torque(Vector3(x_torque, 0.0, z_torque))

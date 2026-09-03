extends MeshInstance3D

@export var source_body: RigidBody3D
@export var fixed_y_degrees: float = -45.0

var original_scale: Vector3

func _ready() -> void:
	original_scale = scale

func _physics_process(_delta: float) -> void:
	if not source_body:
		return

	global_position = source_body.global_position

	var source_rotation: Vector3 = source_body.global_rotation

	global_rotation = Vector3(
		deg_to_rad(90.0) + source_rotation.x,
		deg_to_rad(fixed_y_degrees),
		source_rotation.z
	)

	scale = original_scale

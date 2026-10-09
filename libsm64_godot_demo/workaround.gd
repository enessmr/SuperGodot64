extends RigidBody3D

@export var interpolate: bool = true
@export var mario: Node3D

func _ready() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)
	reset_physics_interpolation()

func _physics_process(_delta: float) -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)
	if mario:
		global_position = mario.global_position

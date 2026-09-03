extends RigidBody3D

@export var mario: Node3D

func _physics_process(_delta):
	if mario:
		global_position = mario.global_position

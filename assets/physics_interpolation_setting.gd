class_name PhysicsInterpolationSetting
extends RefCounted

## Shared helper to make per-node interpolation controls consistent.
static func apply_to(node: Node, enabled: bool) -> void:
	var mode: Node.PhysicsInterpolationMode = Node.PHYSICS_INTERPOLATION_MODE_ON if enabled else Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.physics_interpolation_mode = mode

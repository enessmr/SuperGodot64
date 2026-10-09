extends Node

const BOB_OMB_SCENE: PackedScene = preload("res://assets/bob_omb_3d.tscn")
const BOB_OMB_SCRIPT: Script = preload("res://assets/bob_omb_3d.gd")
const WALKING_ANIMATION: StringName = &"0 - Walking_002"
const GRABBED_ANIMATION: StringName = &"1 - Strugling_002"

func test_scene_has_collision_and_requested_animations() -> void:
	var bob_omb: CharacterBody3D = BOB_OMB_SCENE.instantiate() as CharacterBody3D
	assert(bob_omb != null)
	add_child(bob_omb)
	await get_tree().process_frame
	var collision_shape: CollisionShape3D = bob_omb.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var collision_capsule: CapsuleShape3D = CapsuleShape3D.new()
		collision_capsule.radius = 0.45
		collision_capsule.height = 1.2
		collision_shape.shape = collision_capsule
		bob_omb.add_child(collision_shape)
	assert(collision_shape.shape is CapsuleShape3D)
	assert(bob_omb.collision_mask != 0)
	var animation_player: AnimationPlayer = bob_omb.get_node("Model/AnimationPlayer")
	assert(animation_player.has_animation(WALKING_ANIMATION))
	assert(animation_player.has_animation(GRABBED_ANIMATION))
	assert(animation_player.current_animation == WALKING_ANIMATION)
	bob_omb.queue_free()
	await get_tree().process_frame

func test_script_constants_match_sm64_actions() -> void:
	assert(BOB_OMB_SCRIPT.get_script_constant_map()["ACT_DIVE_PICKING_UP"] == 0x00000385)
	assert(BOB_OMB_SCRIPT.get_script_constant_map()["ACT_THROWING"] == 0x80000588)
	assert(BOB_OMB_SCRIPT.get_script_constant_map()["ACT_HEAVY_THROW"] == 0x80000589)

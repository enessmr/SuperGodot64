extends Node

const BOB_OMB_SCENE: PackedScene = preload("res://assets/bob_omb_3d.tscn")

func test_bob_omb_scene_animation_names_and_script() -> void:
	var bob_omb: Node = BOB_OMB_SCENE.instantiate()
	assert(bob_omb is CharacterBody3D)
	var animation_player: AnimationPlayer = bob_omb.get_node("Model/AnimationPlayer")
	assert(animation_player.has_animation(&"0 - Walking_002"))
	assert(animation_player.has_animation(&"1 - Strugling_002"))
	assert(bob_omb.has_method("play_animation"))
	bob_omb.free()

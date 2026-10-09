# ===========================================
# Bob-omb Buddy (Friendly Bob-omb) Behavior
# ===========================================

class_name SM64BobOmbBuddy
extends CharacterBody3D
## GDScript port of SM64's Bob-omb Buddy behavior

enum BobOmbBuddyState {
	IDLE,
	TALK,
	AFTER_TALK
}

var buddy_state: BobOmbBuddyState = BobOmbBuddyState.IDLE
var mario: LibSM64Mario
var talk_timer: int = 0

@onready var animation_player: AnimationPlayer = get_node_or_null("Model/AnimationPlayer")

func _ready() -> void:
	find_mario()

func _physics_process(delta: float) -> void:
	find_mario()
	
	match buddy_state:
		BobOmbBuddyState.IDLE:
			idle_state(delta)
		BobOmbBuddyState.TALK:
			talk_state(delta)
		BobOmbBuddyState.AFTER_TALK:
			after_talk_state(delta)

func idle_state(delta: float) -> void:
	if mario and global_position.distance_to(mario.global_position) < 300.0:
		buddy_state = BobOmbBuddyState.TALK
		talk_timer = 0
		play_animation("talk")

func talk_state(delta: float) -> void:
	talk_timer += 1
	if talk_timer > 60:  # Talk for 60 frames
		buddy_state = BobOmbBuddyState.AFTER_TALK
		play_animation("idle")

func after_talk_state(delta: float) -> void:
	if mario and global_position.distance_to(mario.global_position) > 400.0:
		buddy_state = BobOmbBuddyState.IDLE

#func give_star_to_mario() -> void:
	# Spawn a star for Mario
	#var star_scene = preload("res://star.tscn")
	#if star_scene:
	#	var star = star_scene.instantiate()
	#	get_parent().add_child(star)
	#	star.global_position = global_position + Vector3.UP * 2.0

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func find_mario() -> void:
	if mario == null or not is_instance_valid(mario):
		var scene_root = get_tree().current_scene
		if scene_root:
			mario = scene_root.find_child("LibSM64Mario", true, false) as LibSM64Mario

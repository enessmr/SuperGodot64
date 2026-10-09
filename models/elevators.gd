extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Drive the PathFollow3D progress with the imported model animation.
	var animation_player: AnimationPlayer = $AnimationPlayer
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_player.play(&"animatablebodyshit")

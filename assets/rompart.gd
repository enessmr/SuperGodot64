extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if SaveManager.has_cached_rom():
		print("Cached ROM found: ", SaveManager.get_rom_path())
		get_tree().change_scene_to_packed(preload("res://models/Nintendo 64 - Super Mario 64 - Miscellaneous - Logo/Logo/intro_logo.tscn"))
	else:
		show()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

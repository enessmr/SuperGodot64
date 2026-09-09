extends Node3D

var _libsm64_was_init := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if SaveManager.has_cached_rom():
		print("Cached ROM found: ", SaveManager.get_rom_path())
		LibSM64Global.load_rom_file(SaveManager.get_rom_path())
	else:
		print("No cached ROM. Open ROM picker.")

	_libsm64_was_init = LibSM64Global.init()
	%LibSM64AudioStreamPlayer.play()
	
	LibSM64.play_music(LibSM64.SEQ_PLAYER_LEVEL, LibSM64.SEQ_MENU_FILE_SELECT)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	pass # Replace with function body.

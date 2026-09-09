extends Node3D

var _libsm64_was_init := false

@onready var intro_camera_rig: Node3D = %CameraRig


func _ready() -> void:
	if SaveManager.has_cached_rom():
		print("Cached ROM found: ", SaveManager.get_rom_path())
		LibSM64Global.load_rom_file(SaveManager.get_rom_path())
		_init_libsm64()
	else:
		print("No cached ROM. Open ROM picker.")


func _init_libsm64() -> void:
	_libsm64_was_init = LibSM64Global.init()

	if not _libsm64_was_init:
		push_error("Failed to initialize LibSM64Global")
		return

	%LibSM64AudioStreamPlayer.play()

	intro_camera_rig.play_lakitu_intro()


func _on_rom_picker_dialog_rom_loaded() -> void:
	_init_libsm64()

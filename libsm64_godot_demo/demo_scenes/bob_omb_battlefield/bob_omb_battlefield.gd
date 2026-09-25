extends Node3D


const BombOmbBattlefieldSurfaces = preload("res://libsm64_godot_demo/levels/bob_omb_battlefield/bob_omb_battlefield_surfaces.gd")

@export var start_cap := LibSM64.MarioFlags.MARIO_NORMAL_CAP

@onready var lib_sm_64_mario: LibSM64Mario = $LibSM64Mario

var _libsm64_was_init := false
var musik: int = 3


func _ready() -> void:
	%BattlefieldMesh.mesh = BombOmbBattlefieldSurfaces.generate_godot_mesh()
	%BattlefieldMesh.mesh.surface_set_material(0, preload("res://libsm64_godot_demo/resources/bob_omb_battlefield_material.tres"))
	# DiscordRPC.app_id = 1544689931560026183
	# DiscordRPC.large_image = "game"
	# DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	# DiscordRPC.refresh()
	if LibSM64Global.rom.is_empty() and not SaveManager.has_cached_rom():
		%RomPickerDialog.pick_rom()
	else:
		LibSM64Global.load_rom_file(SaveManager.get_rom_path())
		_init_libsm64() 


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_toggle_mouse_lock()


func _toggle_mouse_lock() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_tree_exiting():
	if _libsm64_was_init:
		LibSM64.stop_background_music(LibSM64.SEQ_LEVEL_GRASS)
		lib_sm_64_mario.delete()
		LibSM64Global.terminate()


func _init_libsm64() -> void:
	_libsm64_was_init = LibSM64Global.init()
	if not _libsm64_was_init:
		push_error("Failed to initialize LibSM64Global")
		return
		
	%LibSM64StaticSurfacesHandler.load_static_surfaces()
	BombOmbBattlefieldSurfaces.load_static_surfaces()
	%LibSM64SurfaceObjectsHandler.load_all_surface_objects()

	# allow one physics frame so surface nodes are fully registered
	await get_tree().physics_frame

	print("LibSM64: ROM size=", LibSM64Global.rom.size())
	print("LibSM64: mario_texture is null?", LibSM64Global.mario_texture == null)

	lib_sm_64_mario.create()
	print("LibSM64: Mario id=", lib_sm_64_mario.id, " action=", lib_sm_64_mario.action_name)
	if lib_sm_64_mario.id < 0:
		push_error("LibSM64: Mario failed to create (id < 0)")
	elif lib_sm_64_mario.action == LibSM64.ActionFlags.ACT_UNINITIALIZED:
		push_warning("LibSM64: Mario action uninitialized after create; waiting for first tick")

	lib_sm_64_mario.interact_cap(start_cap)

	%DebugHUD.mario = lib_sm_64_mario
	%HUD._mario = lib_sm_64_mario

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	%LevelGlobals.music = musik
	%LevelGlobals.play_musik()
	%LibSM64AudioStreamPlayer.play()
	lib_sm_64_mario.lives_changed.emit()
	var YellowBoxStar2 = $ChainChompStar
	YellowBoxStar2.global_position = global_position 
			
	%LevelGlobals.star_spawn(
				YellowBoxStar2,
				%ChainChompStarLoc,
				%CameraRig,
				lib_sm_64_mario,
				true,
				2,
				false
			)


func _on_rom_picker_dialog_rom_loaded() -> void:
	_init_libsm64()

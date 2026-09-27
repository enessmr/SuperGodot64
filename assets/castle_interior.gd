extends Node3D

@export var start_cap := LibSM64.MarioFlags.MARIO_NORMAL_CAP

@onready var lib_sm_64_mario: LibSM64Mario = $LibSM64Mario

var _libsm64_was_init := false
var musik: int = 4


func _ready() -> void:
	# DiscordRPC.app_id = 1544689931560026183
	# DiscordRPC.large_image = "game"
	# DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	# DiscordRPC.refresh()
	if %RomPickerDialog:
		%RomPickerDialog.rom_loaded.connect(_on_rom_picker_dialog_rom_loaded)
	
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
		lib_sm_64_mario.delete()
		LibSM64Global.terminate()


func _init_libsm64() -> void:
	_libsm64_was_init = LibSM64Global.init()
	if not _libsm64_was_init:
		push_error("Failed to initialize LibSM64Global")
		return
	
	%LibSM64SurfaceObjectsHandler.load_all_surface_objects()
	%LibSM64StaticSurfacesHandler.load_static_surfaces()

	print("LibSM64: ROM size=", LibSM64Global.rom.size())
	print("LibSM64: mario_texture is null?", LibSM64Global.mario_texture == null)

	# create Mario
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

	%LevelGlobals.music_index = musik
	%LevelGlobals.play_musik(start_cap)
	lib_sm_64_mario.interact_cap(start_cap)
	%LibSM64AudioStreamPlayer.play()
	var painting: Node = get_node_or_null(
	"Area1_bake/Objects/P0x0_Bob-omb_Battlefield/Painting0/Node0_root/Node1_scale/Mesh2"
	)

	print("Painting node: ", painting)

	if painting != null:
		painting.set("painting_size", 8.0)
	$"Area1_bake/Objects/P0x0_Bob-omb_Battlefield/Painting0/Node0_root/Node1_scale/Mesh3".painting_size = 6
	$"Area1_bake/Objects/P0x0_Bob-omb_Battlefield/Painting0/Node0_root/Node1_scale/Mesh3".painting_width = 6
	$"Area1_bake/Objects/P0x0_Bob-omb_Battlefield/Painting0/Node0_root/Node1_scale/Mesh3".painting_height = 6
	$"Area1_bake/Objects/0xDD_Toad/toad".player = lib_sm_64_mario
	$"Area1_bake/Objects/0xDD_Toad2/toad".player = lib_sm_64_mario
	$"Area1_bake/Objects/0xDD_Toad3/toad".player = lib_sm_64_mario


func _on_rom_picker_dialog_rom_loaded() -> void:
	_init_libsm64()

extends Node3D

var _libsm64_was_init := false
var course_number: int = 1

var _stars: Array[PowerStar3D] = []
var _selected_index: int = 0
var _loading: bool = false

# TODO: implement save slot selection. Falls back to slot A for now.
var _save_slot: String = "a"

# Level to load when pressing A on the hovered star.
# Settable in the inspector OR in code: star_select.level_path = "res://levels/course_1.tscn"
@export_file("*.tscn", "*.scn", "*.tres") var level_path: String = ""

const COLLECTED_STAR_MESH: Mesh = preload("res://models/star.tres")

const DIGIT_ANIMATIONS: Array[StringName] = [
	&"segment2.00000.rgba16",
	&"segment2.00200.rgba16",
	&"segment2.00400.rgba16",
	&"segment2.00600.rgba16",
	&"segment2.00800.rgba16",
	&"segment2.00A00.rgba16",
	&"segment2.00C00.rgba16",
	&"segment2.00E00.rgba16",
	&"segment2.01000.rgba16",
	&"segment2.01200.rgba16",
]

const MINUS_ANIMATION: StringName = &"segment2.02C00.rgba16"


func _ready() -> void:
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


func _process(_delta: float) -> void:
	if _stars.is_empty():
		return

	# Move left (A) — stops at the lowest star id.
	if Input.is_action_just_pressed(&"libsm64_mario_inputs_stick_left"):
		if _selected_index > 0:
			_selected_index -= 1
			_update_hover()
			LibSM64.play_sound_global(LibSM64.SOUND_MENU_CHANGE_SELECT)

	# Move right (D) — stops at the highest star id.
	if Input.is_action_just_pressed(&"libsm64_mario_inputs_stick_right"):
		if _selected_index < _stars.size() - 1:
			_selected_index += 1
			_update_hover()
			LibSM64.play_sound_global(LibSM64.SOUND_MENU_CHANGE_SELECT)

	# Press A (jump) on the hovered star → load the level.
	if Input.is_action_just_pressed(&"libsm64_mario_inputs_button_a"):
		_enter_level()


func _enter_level() -> void:
	if _loading:
		return

	level_path = CustomGlobals.scene

	if level_path.is_empty():
		push_error("StarSelect: No level_path set!")
		return

	var scene: PackedScene = load(level_path)

	if scene == null:
		push_error("StarSelect: Failed to load level: " + level_path)
		return

	_loading = true

	# Stash the selected star id so the level knows which star to spawn.
	CustomGlobals.selected_star_id = _stars[_selected_index].star_id

	get_tree().change_scene_to_packed(scene)


func _on_tree_exiting():
	if _libsm64_was_init:
		LibSM64Global.terminate()


func _init_libsm64() -> void:
	_libsm64_was_init = LibSM64Global.init()
	if not _libsm64_was_init:
		push_error("Failed to initialize LibSM64Global")
		return

	%CourseLabel.text = ""
	%Stars.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().create_timer(0.4).timeout
	_render_course_number()
	%Stars.show()
	course_number = CustomGlobals.course_number
	_select_lowest_star()
	%CourseLabel.text = CustomGlobals.course_name
	%LibSM64AudioStreamPlayer.play()
	LibSM64.play_music(LibSM64.SEQ_PLAYER_LEVEL, LibSM64.SEQ_MENU_STAR_SELECT)


func _collect_stars() -> void:
	_stars.clear()

	for child in %Stars.get_children():
		if child is PowerStar3D:
			_stars.append(child)

	# Sort by star_id so index 0 is always the lowest id.
	_stars.sort_custom(
		func(a: PowerStar3D, b: PowerStar3D) -> bool:
			return a.star_id < b.star_id
	)

	# Swap meshes for stars already collected in the save file.
	for star in _stars:
		if SaveManager.is_star_collected(_save_slot, course_number, star.star_id):
			if is_instance_valid(star.mesh):
				star.mesh.mesh = COLLECTED_STAR_MESH


func _select_lowest_star() -> void:
	_collect_stars()

	if _stars.is_empty():
		return

	_selected_index = 0
	_update_hover()


func _update_hover() -> void:
	for i in _stars.size():
		# Reset the mesh rotation back to 0 degrees.
		if is_instance_valid(_stars[i].mesh):
			_stars[i].mesh.rotation_degrees = Vector3(-90, 0, 0)
	
		_stars[i].hover = (i == _selected_index)

	# Show the hovered star's name.
	%StarLabel.text = _stars[_selected_index].star_name


func _on_rom_picker_dialog_rom_loaded() -> void:
	_init_libsm64()


func _render_course_number() -> void:
	var value: int = clamp(CustomGlobals.course_number, 1, 15)

	var ones: int = value % 10
	var tens: int = (value / 10) % 10

	# Center digit
	if value <= 10:
		%CourseNumberCenter.animation = DIGIT_ANIMATIONS[ones]
		%CourseNumberCenter.frame = 0
		%CourseNumberCenter.show()

	# Tens and ones digit
	if value >= 10:
		%CourseNumberCenter.hide()
		%CourseNumberTens.animation = DIGIT_ANIMATIONS[tens]
		%CourseNumberTens.frame = 0
		%CourseNumberTens.show()
		%CourseNumberOnes.animation = DIGIT_ANIMATIONS[ones]
		%CourseNumberOnes.frame = 0
		%CourseNumberOnes.show()
	else:
		%CourseNumberTens.hide()
		%CourseNumberOnes.hide()
	
	# In SM64, there are only 15 courses that does the star select.

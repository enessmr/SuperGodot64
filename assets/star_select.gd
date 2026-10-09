extends Node3D

var _libsm64_was_init := false
var course_number: int = 1

@onready var stars_amount_1 = %StarsAmount1
@onready var stars_amount_2 = %StarsAmount2
@onready var stars_amount_3 = %StarsAmount3
@onready var stars_amount_4 = %StarsAmount4
@onready var stars_amount_5 = %StarsAmount5
@onready var stars_amount_6 = %StarsAmount6

var _stars: Array[PowerStar3D] = []
var _selected_index: int = 0
var _loading: bool = false

var _save_slot: String = "a"

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


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return

		print("KEY PRESSED: ", event.keycode)

		if event.keycode == KEY_A:
			_move_selection(-1)
		elif event.keycode == KEY_D:
			_move_selection(1)
		elif event.keycode == KEY_ENTER:
			_enter_level()
		elif event.keycode == KEY_SPACE:
			_enter_level()
		elif event.keycode == KEY_ESCAPE:
			_toggle_mouse_lock()


func _process(_delta: float) -> void:
	if _stars.is_empty():
		return

	if Input.is_action_just_pressed(
		&"libsm64_mario_inputs_stick_left"
	):
		_move_selection(-1)

	if Input.is_action_just_pressed(
		&"libsm64_mario_inputs_stick_right"
	):
		_move_selection(1)


func _move_selection(direction: int) -> void:
	var visible_stars: Array[PowerStar3D] = []

	for star: PowerStar3D in _stars:
		if star.is_visible_in_tree():
			visible_stars.append(star)

	print(
		"MOVE SELECTION | direction=",
		direction,
		" | visible=",
		visible_stars.size(),
		" | current=",
		_selected_index
	)

	if visible_stars.is_empty():
		print("NO VISIBLE STARS")
		return

	var new_index: int = _selected_index + direction

	if new_index < 0:
		new_index = 0

	if new_index >= visible_stars.size():
		new_index = visible_stars.size() - 1

	if new_index == _selected_index:
		print("Already at selection boundary.")
		return

	_selected_index = new_index

	print("NEW SELECTED INDEX: ", _selected_index)

	_update_hover()

	LibSM64.play_sound_global(
		LibSM64.SOUND_MENU_CHANGE_SELECT
	)


func _enter_level() -> void:
	if _loading:
		return

	if _stars.is_empty():
		return

	var visible_stars: Array[PowerStar3D] = []

	for star: PowerStar3D in _stars:
		if star.is_visible_in_tree():
			visible_stars.append(star)

	if visible_stars.is_empty():
		return

	_selected_index = clamp(
		_selected_index,
		0,
		visible_stars.size() - 1
	)

	level_path = CustomGlobals.scene

	if level_path.is_empty():
		push_error("StarSelect: No level_path set!")
		return

	var scene: PackedScene = load(level_path)

	if scene == null:
		push_error("StarSelect: Failed to load level: " + level_path)
		return

	_loading = true

	CustomGlobals.selected_star_id = visible_stars[_selected_index].star_id

	get_tree().change_scene_to_packed(scene)


func _on_tree_exiting() -> void:
	if _libsm64_was_init:
		LibSM64Global.terminate()


func _init_libsm64() -> void:
	_libsm64_was_init = LibSM64Global.init()

	if not _libsm64_was_init:
		push_error("Failed to initialize LibSM64Global")
		return

	_render_course_number()

	course_number = CustomGlobals.course_number
	%CourseLabel.text = CustomGlobals.course_name

	%Stars.hide()

	await get_tree().create_timer(0.4).timeout

	%Stars.show()

	print("STAR AMOUNT = ", CustomGlobals.star_amount)

	update_star_amount_visibility()
	_select_lowest_star()

	%LibSM64AudioStreamPlayer.play()

	LibSM64.play_music(
		LibSM64.SEQ_PLAYER_LEVEL,
		LibSM64.SEQ_MENU_STAR_SELECT
	)


func _collect_stars() -> void:
	_stars.clear()

	_find_power_stars(%Stars)

	# Star Select is shared by every course. Apply the course's exported data
	# to only the currently visible display stars, in their scene order.
	var visible_stars: Array[PowerStar3D] = []
	for star: PowerStar3D in _stars:
		if star.is_visible_in_tree():
			visible_stars.append(star)

	var course_star_ids: Array[int] = []
	var course_star_names: Array[String] = []
	var raw_star_ids: Variant = CustomGlobals.get("star_ids")
	var raw_star_names: Variant = CustomGlobals.get("star_names")
	if raw_star_ids is Array:
		for star_id: Variant in raw_star_ids:
			course_star_ids.append(int(star_id))
	if raw_star_names is Array:
		for star_name: Variant in raw_star_names:
			course_star_names.append(str(star_name))
	for i: int in visible_stars.size():
		var star: PowerStar3D = visible_stars[i]
		if i < course_star_ids.size():
			star.star_id = course_star_ids[i]
		if i < course_star_names.size():
			star.star_name = course_star_names[i]
		else:
			star.star_name = "Star %d" % (star.star_id)

	_stars = visible_stars
	_stars.sort_custom(func(a: PowerStar3D, b: PowerStar3D) -> bool:
		return a.star_id < b.star_id
	)

	print("FOUND ", _stars.size(), " VISIBLE POWER STARS")

	for i in _stars.size():
		var star: PowerStar3D = _stars[i]

		star.hover = false

		print(
			"STAR ",
			i,
			" | ID=",
			star.star_id,
			" | visible_in_tree=",
			star.is_visible_in_tree()
		)

		if SaveManager.is_star_collected(
			_save_slot,
			course_number,
			star.star_id
		):
			if is_instance_valid(star.mesh):
				star.mesh.mesh = COLLECTED_STAR_MESH


func _find_power_stars(node: Node) -> void:
	for child: Node in node.get_children():
		if child is PowerStar3D:
			_stars.append(child as PowerStar3D)

		_find_power_stars(child)


func _select_lowest_star() -> void:
	_collect_stars()

	var visible_stars: Array[PowerStar3D] = []

	for star: PowerStar3D in _stars:
		if star.is_visible_in_tree():
			visible_stars.append(star)

	if visible_stars.is_empty():
		print("NO VISIBLE STARS")
		return

	_selected_index = 0

	print(
		"INITIAL SELECTED INDEX: ",
		_selected_index,
		" | VISIBLE STARS: ",
		visible_stars.size()
	)

	_update_hover()


func _update_hover() -> void:
	var visible_stars: Array[PowerStar3D] = []

	for star: PowerStar3D in _stars:
		if star.is_visible_in_tree():
			visible_stars.append(star)

	if visible_stars.is_empty():
		return

	_selected_index = clamp(
		_selected_index,
		0,
		visible_stars.size() - 1
	)

	print("UPDATING HOVER: ", _selected_index)

	for star: PowerStar3D in _stars:
		star.hover = false

	for i in visible_stars.size():
		var star: PowerStar3D = visible_stars[i]

		star.hover = i == _selected_index

		if is_instance_valid(star.mesh):
			if i == _selected_index:
				star.mesh.rotation_degrees = Vector3(
					-90.0,
					0.0,
					0.0
				)
			else:
				star.mesh.rotation_degrees = Vector3(
					-90.0,
					0.0,
					20.0
				)

	%StarLabel.text = visible_stars[_selected_index].star_name


func _toggle_mouse_lock() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_rom_picker_dialog_rom_loaded() -> void:
	_init_libsm64()


func _render_course_number() -> void:
	var value: int = clamp(CustomGlobals.course_number, 1, 15)

	var ones: int = value % 10
	var tens: int = (value / 10) % 10

	if value <= 10:
		%CourseNumberCenter.animation = DIGIT_ANIMATIONS[ones]
		%CourseNumberCenter.frame = 0
		%CourseNumberCenter.show()

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


func update_star_amount_visibility() -> void:
	stars_amount_1.visible = CustomGlobals.star_amount == 1
	stars_amount_2.visible = CustomGlobals.star_amount == 2
	stars_amount_3.visible = CustomGlobals.star_amount == 3
	stars_amount_4.visible = CustomGlobals.star_amount == 4
	stars_amount_5.visible = CustomGlobals.star_amount == 5
	stars_amount_6.visible = CustomGlobals.star_amount == 6

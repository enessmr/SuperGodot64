extends CanvasLayer

var pause_menu_open := false

@onready var _mario: LibSM64Mario = null
@onready var pause_menu_panel := %PauseMenuPanel as PanelContainer
@export var current: CanvasLayer


func _ready() -> void:
	_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario

	if pause_menu_panel:
		pause_menu_panel.visible = false

	_sync_pause_state()


func _process(_delta: float) -> void:
	_sync_pause_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_toggle_pause_menu()

	elif event.is_action_pressed(&"pause_frame_advance"):
		if _mario and _mario.play_mode == LibSM64Mario.PlayMode.PAUSED:
			_on_frame_advance_button_pressed()


func _sync_pause_state() -> void:
	if not _mario:
		return

	var is_paused := _mario.play_mode == LibSM64Mario.PlayMode.PAUSED
	pause_menu_open = is_paused

	if pause_menu_panel:
		pause_menu_panel.visible = is_paused

	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _toggle_pause_menu() -> void:
	if not _mario:
		return

	if _mario.play_mode == LibSM64Mario.PlayMode.PAUSED:
		pause_menu_panel.hide()
		LibSM64.play_sound_global(LibSM64.SOUND_MENU_PAUSE)
		_mario.resume_game()
	else:
		pause_menu_panel.show()
		LibSM64.play_sound_global(LibSM64.SOUND_MENU_PAUSE)
		_mario.pause_game()

	_sync_pause_state()


func _on_resume_button_pressed() -> void:
	_toggle_pause_menu()


func _on_frame_advance_button_pressed() -> void:
	if not _mario:
		return

	_mario.advance_one_frame()

	pause_menu_open = true

	if pause_menu_panel:
		pause_menu_panel.visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_return_button_pressed() -> void:
	if _mario:
		_mario.resume_game()

	_sync_pause_state()

	var main_node := get_tree().root.get_child(-1)

	if main_node.has_method(&"return_to_menu"):
		main_node.return_to_menu()


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://libsm64_godot_demo/main.tscn")

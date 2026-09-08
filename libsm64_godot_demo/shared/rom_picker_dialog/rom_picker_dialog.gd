extends FileDialog


signal rom_loaded


var _file_access_web: FileAccessWeb


func pick_rom() -> void:
	if OS.get_name() == "Web":
		_file_access_web = FileAccessWeb.new()
		_file_access_web.loaded.connect(_on_file_access_web_loaded)
		_file_access_web.open(".n64, .z64")
	else:
		popup_centered_ratio()


func _on_file_selected(path: String) -> void:
	if LibSM64Global.load_rom_file(path):
		rom_loaded.emit()
		if CustomGlobals.TitleWindow:
			%CorrectRomLabel.show()
			%PickRomLabel.hide()
			%WrongRomLabel.hide()
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_packed(preload("res://models/Nintendo 64 - Super Mario 64 - Miscellaneous - Logo/Logo/intro_logo.tscn"))
	else:
		if CustomGlobals.TitleWindow:
			%InvalidRomDialog.popup_centered()
			%WrongRomLabel.show()
			%PickRomLabel.hide()


func _on_file_access_web_loaded(_file_name: String, _type: String, base64_data: String) -> void:
	if LibSM64Global.load_rom_from_base64_string(base64_data):
		rom_loaded.emit()
	else:
		%InvalidRomDialog.popup_centered()

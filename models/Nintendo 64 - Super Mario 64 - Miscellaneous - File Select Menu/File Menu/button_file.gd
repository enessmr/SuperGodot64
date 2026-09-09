extends Node3D


func _ready() -> void:
	var slot := name.trim_prefix("ButtonFile").to_lower()

	if not SaveManager.is_valid_slot(slot):
		push_error("Invalid file select node name: " + name)
		return

	SaveManager.ensure_save_file(slot)

	var data: Variant = SaveManager.load_file(slot)

	if data == null:
		print(name, ": Failed to load")
		return

	if data is Dictionary and data.get("empty", false):
		print(name, ": Empty")
		%Mesh1_NoFile.show()
		%Mesh1.hide()
	else:
		print(name, ": Loaded ", data)
		%Mesh1_NoFile.hide()
		%Mesh1.show()

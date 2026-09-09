extends Node

const SAVE_DIR := "user://saves/"
const ROM_PATH := SAVE_DIR + "resource.z64"

const SAVE_PATHS := {
	"a": SAVE_DIR + "save_a.dat",
	"b": SAVE_DIR + "save_b.dat",
	"c": SAVE_DIR + "save_c.dat",
	"d": SAVE_DIR + "save_d.dat"
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ============================================================
# ROM
# ============================================================

func has_cached_rom() -> bool:
	return FileAccess.file_exists(ROM_PATH)


func get_rom_path() -> String:
	return ROM_PATH


func get_rom_data() -> PackedByteArray:
	if not has_cached_rom():
		return PackedByteArray()

	var file := FileAccess.open(ROM_PATH, FileAccess.READ)

	if file == null:
		push_error("SaveManager: Failed to open cached ROM.")
		return PackedByteArray()

	return file.get_buffer(file.get_length())


func set_rom_from_picker(source_path: String) -> bool:
	if source_path.is_empty():
		return false

	var source := FileAccess.open(source_path, FileAccess.READ)

	if source == null:
		push_error("SaveManager: Could not open selected ROM: " + source_path)
		return false

	var rom_data := source.get_buffer(source.get_length())
	source.close()

	if rom_data.is_empty():
		push_error("SaveManager: Selected ROM is empty.")
		return false

	var destination := FileAccess.open(ROM_PATH, FileAccess.WRITE)

	if destination == null:
		push_error("SaveManager: Could not create cached ROM.")
		return false

	destination.store_buffer(rom_data)
	destination.close()

	print("SaveManager: Cached ROM at ", ROM_PATH)

	return true


# ============================================================
# SAVE FILES
# ============================================================

func is_valid_slot(slot: String) -> bool:
	return SAVE_PATHS.has(slot.to_lower())


func get_save_path(slot: String) -> String:
	slot = slot.to_lower()

	if not is_valid_slot(slot):
		return ""

	return SAVE_PATHS[slot]


func file_exists(slot: String) -> bool:
	var path := get_save_path(slot)

	if path.is_empty():
		return false

	return FileAccess.file_exists(path)


func save_file(slot: String, data: Variant) -> bool:
	var path := get_save_path(slot)

	if path.is_empty():
		push_error("SaveManager: Invalid save slot: " + slot)
		return false

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("SaveManager: Could not open save file for writing: " + path)
		return false

	file.store_var(data)
	file.close()

	print("SaveManager: Saved File ", slot.to_upper())

	return true


func load_file(slot: String) -> Variant:
	var path := get_save_path(slot)

	if path.is_empty():
		push_error("SaveManager: Invalid save slot: " + slot)
		return null

	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("SaveManager: Could not open save file: " + path)
		return null

	var data: Variant = file.get_var()
	file.close()

	return data


func ensure_save_file(slot: String) -> bool:
	slot = slot.to_lower()

	if not is_valid_slot(slot):
		push_error("SaveManager: Invalid save slot: " + slot)
		return false

	if file_exists(slot):
		return true

	var empty_save := {
		"empty": true,
		"stars": 0,
		"coins": 0,
		"lives": 4
	}

	return save_file(slot, empty_save)


func delete_file(slot: String) -> bool:
	var path := get_save_path(slot)

	if path.is_empty():
		push_error("SaveManager: Invalid save slot: " + slot)
		return false

	if not FileAccess.file_exists(path):
		return true

	var error := DirAccess.remove_absolute(path)

	if error != OK:
		push_error("SaveManager: Failed to delete " + path)
		return false

	print("SaveManager: Deleted File ", slot.to_upper())

	return true

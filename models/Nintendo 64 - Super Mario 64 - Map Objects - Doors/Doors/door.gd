extends Node3D

@export_category("Normal Doors")
@export var cabinet_door: bool = false
@export var castle_door: bool = true
@export var metal_door: bool = false
@export var spooky_door: bool = false
@export var H_M_C_door: bool = false
@export var wood_door: bool = false

@export_category("Special Doors")
@export var castle_star_door: bool = false

@export_category("Double Doors")
@export var double_locked_door: bool = false
@export var double_star_door: bool = false


func _ready() -> void:
	_update_door_visibility()


func _update_door_visibility() -> void:
	# Normal doors
	_set_visibility("Parent To All Rotations/Cabinet Door", cabinet_door)
	_set_visibility("Parent To All Rotations/Castle Door", castle_door)
	_set_visibility("Parent To All Rotations/Metal Door", metal_door)
	_set_visibility("Parent To All Rotations/Spooky Door", spooky_door)
	_set_visibility("Parent To All Rotations/HMC Door", H_M_C_door)
	_set_visibility("Parent To All Rotations/Wood Door", wood_door)

	# Special doors
	_set_visibility("Parent To All Rotations/Castle Star Door", castle_star_door)

	# Double doors
	_set_visibility("Parent to All Rotations (Double Doors)/Locked Door", double_locked_door)
	_set_visibility("Parent to All Rotations (Double Doors)/Star Door (yes, this is one part)", double_star_door)

	# Hide the normal rotation parent if all normal doors are disabled
	var any_normal_door := (
		cabinet_door
		or castle_door
		or metal_door
		or spooky_door
		or H_M_C_door
		or wood_door
	)

	var rotation_parent := get_node_or_null("Parent To All Rotations") as Node3D

	if rotation_parent:
		rotation_parent.visible = any_normal_door

	# Hide the double-door container if no double door is selected
	var any_double_door := (
		double_locked_door
		or double_star_door
	)

	var double_rotation_parent := get_node_or_null("Parent to All Rotations (Double Doors)") as Node3D

	if double_rotation_parent:
		double_rotation_parent.visible = any_double_door


func _set_visibility(node_path: String, enabled: bool) -> void:
	var node := get_node_or_null(node_path) as Node3D

	if node:
		node.visible = enabled

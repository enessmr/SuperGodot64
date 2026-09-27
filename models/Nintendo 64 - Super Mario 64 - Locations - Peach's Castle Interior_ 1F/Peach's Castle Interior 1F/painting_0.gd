extends Node3D

var _mario: LibSM64Mario = null

@export var course_id := 1
@export var course_name := "BOB-OMB BATTLEFIELD"
@export var course_number := 1

@export var star_ids: Array[int] = [1, 2, 3, 4, 5, 6]

@export var star_names: Array[String] = [
	"Shoot to the Island in the Sky",
	"Behind Chain Chomp's Gate"
]

func _ready() -> void:
	_find_mario()

func _find_mario() -> void:
	_mario = get_tree().current_scene.find_child(
		"LibSM64Mario",
		true,
		false
	) as LibSM64Mario

	$Node0_root/Node1_scale/Mesh3.mario = _mario
	$Node0_root/Node1_scale/Mesh3._course_id = course_id
	$Node0_root/Node1_scale/Mesh3._course_name = course_name
	$Node0_root/Node1_scale/Mesh3._course_number = course_number

func get_star_name(star_id: int) -> String:
	var index := star_ids.find(star_id)

	if index == -1:
		return "Unknown Star"

	if index >= star_names.size():
		return "Unknown Star"

	return star_names[index]

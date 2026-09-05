# The sole purpose of this script is to give the wing cap box a group name...
@icon("res://models/WCBox_ICON.svg")
class_name EBox3D
extends MeshInstance3D

@export var give_radius := 2.0
@export var respawnable: bool = false
@export var respawn_time := 0.0
@export var object_spawnable: ExclamationBoxSpawnableObjects
@export var YellowBoxStar: Node3D

var _used := false
var _mario: LibSM64Mario = null


func _ready() -> void:
	_find_mario()


func _find_mario() -> void:
	_mario = get_tree().current_scene.find_child(
		"LibSM64Mario",
		true,
		false
	) as LibSM64Mario


func _physics_process(_delta: float) -> void:
	if _used:
		return

	if not is_instance_valid(_mario):
		_find_mario()

		if not is_instance_valid(_mario):
			return

	var d := global_position.distance_to(_mario.global_position)

	if d <= give_radius:
		_spawn_obj()


func _spawn_obj() -> void:
	if _used:
		return

	_used = true

	# Spawn the object first.
	if _mario and object_spawnable:
		obj_matching_spawning(object_spawnable)

	# Hide this box.
	visible = false

	if respawnable:
		await get_tree().create_timer(respawn_time).timeout

		_used = false
		visible = true


func obj_matching_spawning(
	object_spawnable1: ExclamationBoxSpawnableObjects
) -> void:
	match object_spawnable1.object_type:
		"Triple Coins":
			# Spawn triple coins
			pass

		"Coin":
			# Spawn coin
			pass

		"1-Up":
			# Spawn 1-Up
			pass

		"Star":
			# Move the star to the box's position before starting the cutscene
			YellowBoxStar.global_position = global_position 
			
			%LevelGlobals.star_spawn(
				YellowBoxStar,
				%YellowBoxStarLocation,
				%CameraRig,
				_mario,
				true,
				2
			)

		"Bob-omb":
			# Spawn Bob-omb
			pass

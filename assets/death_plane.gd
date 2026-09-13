@icon("res://models/DeathPlane_ICON.svg")
class_name DeathPlane
extends MeshInstance3D

@export_category("Death Plane")
@export var secret_level_plane := false

@export_category("Scene Warp")
@export_file("*.tscn") var destination_scene: String
@export var spawn_marker_name := "SpawnMarker"

@export_category("Mario")
@export var death_radius := 1.0

var _used := false
@onready var _mario: LibSM64Mario = null


func _ready() -> void:
	_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario


func _physics_process(delta: float) -> void:
	if _used:
		return

	if not _mario:
		_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario
		if not _mario:
			return

	var d := global_transform.origin.distance_to(_mario.global_transform.origin)

	if d <= death_radius:
		_die()


func _die() -> void:
	if _used:
		return

	_used = true

	# Both normal and secret death planes play the Bowser laugh.
	LibSM64.play_sound_global(LibSM64.SOUND_OBJ_BOWSER_LAUGH)

	# Both types still kill Mario.
	# The difference is that a Secret Level Plane does not remove a life
	# or trigger the normal death animation after the warp.
	if _mario:
		_mario.kill()

	# Normal death plane uses the normal death handling.
	if not secret_level_plane:
		if has_node("/root/LevelGlobals"):
			var level_globals = get_node("/root/LevelGlobals")

			if level_globals.has_method("player_died"):
				level_globals.player_died()
			elif level_globals.has_method("mario_died"):
				level_globals.mario_died()
			elif level_globals.has_method("lose_life"):
				level_globals.lose_life()

	# Change scene after the death has been triggered.
	if not destination_scene.is_empty():
		await get_tree().process_frame
		get_tree().change_scene_to_file(destination_scene)

# The sole purpose of this script is to give the wing cap box a group name...
@icon("res://models/WCBox_ICON.svg")
class_name WCBox3D
extends MeshInstance3D

@export var cap_time := 100.0
@export var give_radius := 2.0
@export var meshwc: WCBox3D # i cant do shit

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
	if d <= give_radius:
		_give_wing_cap()

func _on_used():
	if not _used:
		return
	await get_tree().create_timer(5.0).timeout
	_used = false
	if meshwc:
		meshwc.visible = true
	

func _give_wing_cap() -> void:
	if _used:
		return
	_used = true
	if _mario:
		_mario.interact_cap(LibSM64.MarioFlags.MARIO_WING_CAP, cap_time)

	# hide visual mesh if present, then free shortly after
	if meshwc:
		meshwc.visible = false
	_on_used()

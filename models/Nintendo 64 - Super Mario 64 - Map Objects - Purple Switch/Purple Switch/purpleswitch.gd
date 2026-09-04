extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area3D = $Area3D

var mario_on_switch := false
var current_state := "Rest"


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_play_state("Rest")


func _play_state(state: String) -> void:
	if current_state == state:
		return

	current_state = state
	animation_player.play(state)


func _on_body_entered(body: Node3D) -> void:
	if body.name != "MarioRB":
		return

	if mario_on_switch:
		return

	mario_on_switch = true

	_play_state("Push")

	await animation_player.animation_finished

	if mario_on_switch:
		_play_state("RestHold")


func _on_body_exited(body: Node3D) -> void:
	if body.name != "MarioRB":
		return

	if not mario_on_switch:
		return

	mario_on_switch = false

	_play_state("Release")

	await animation_player.animation_finished

	if not mario_on_switch:
		_play_state("Rest")

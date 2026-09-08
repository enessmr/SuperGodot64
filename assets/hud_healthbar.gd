extends CanvasLayer

@export var anim: AnimationPlayer
@onready var _mario: LibSM64Mario = null

func _ready() -> void:
	_find_mario()


func _find_mario() -> void:
	if is_instance_valid(_mario):
		if not _mario.health_wedges_changed.is_connected(_on_health_changed):
			_mario.health_wedges_changed.connect(_on_health_changed)
		_update_health_bar()
		return

	var mario := get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario
	if not mario:
		mario = get_tree().get_first_node_in_group("libsm64_mario") as LibSM64Mario

	if not mario:
		return

	_mario = mario
	_mario.health_wedges_changed.connect(_on_health_changed)
	_update_health_bar()


func _on_health_changed(_health_wedges: int) -> void:
	_update_health_bar()


func _update_health_bar() -> void:
	if not is_instance_valid(_mario):
		return

	var health: int = clamp(_mario.health_wedges, 0, 8)

	%bar_full.visible = health == 8
	%bar_7.visible = health == 7
	%bar_6.visible = health == 6
	%bar_5.visible = health == 5
	%bar_4.visible = health == 4
	%bar_3.visible = health == 3
	%bar_2.visible = health == 2
	%bar_1.visible = health == 1

	if health <= 0:
		%bar_full.visible = false
		%bar_7.visible = false
		%bar_6.visible = false
		%bar_5.visible = false
		%bar_4.visible = false
		%bar_3.visible = false
		%bar_2.visible = false
		%bar_1.visible = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_mario):
		_find_mario()
		return

	_update_health_bar()

extends CanvasLayer

@export var anim: AnimationPlayer
@onready var _mario: LibSM64Mario = null

func _ready() -> void:
	_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario


func _process(_delta: float) -> void:
	if not _mario:
		_mario = get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario
		if not _mario:
			return

	var health: int = _mario.health_wedges

	%bar_full.visible = health == 8
	%bar_7.visible = health == 7
	%bar_6.visible = health == 6
	%bar_5.visible = health == 5
	%bar_4.visible = health == 4
	%bar_3.visible = health == 3
	%bar_2.visible = health == 2
	%bar_1.visible = health == 1

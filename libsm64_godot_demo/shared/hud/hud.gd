extends PanelContainer

const MARIO_INFO_FORMAT := """
Action: %s
Health wedges: %d
Invicibility Time: %.2f
Face angle: %dº
Forward velocity: %.2f"""

var mario: LibSM64Mario

@onready var mario_info_label := %MarioInfoLabel as Label

func _process(_delta: float) -> void:
	if mario:
		mario_info_label.text = MARIO_INFO_FORMAT % [
			mario.action_name,
			mario.health_wedges,
			mario.invincibility_time,
			rad_to_deg(mario.face_angle),
			mario.forward_velocity
		]

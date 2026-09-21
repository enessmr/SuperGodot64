extends CanvasLayer

@export var anim: AnimationPlayer
@export var power_meter: Control

@export var _mario: LibSM64Mario = null

const HIDDEN_Y: float = 166
const VISIBLE_Y: float = 287.0
const HIDE_Y: float = 300.0

const EMPHASIZED_SPEED: float = 50
const HIDE_SPEED: float = 40.0
const FULL_HEALTH_HIDE_DELAY: float = 45.0 / 30.0

var _power_meter_y: float = HIDDEN_Y
var _visible_timer: float = 0.0
var _state: int = 0

const HIDDEN := 0
const EMPHASIZED := 1
const DEEMPHASIZING := 2
const VISIBLE := 3
const HIDING := 4


func _ready() -> void:
	_find_mario()

	if is_instance_valid(power_meter):
		_power_meter_y = power_meter.position.y


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

	_handle_power_meter_state(health)


func _handle_power_meter_state(health: int) -> void:
	if health < 8:
		if _state == HIDDEN:
			_state = EMPHASIZED
			_power_meter_y = HIDDEN_Y
			_visible_timer = 0.0

	elif health == 8:
		if _state == 7:
			_visible_timer = 0.0

		# Original SM64 waits 45 frames before hiding.
		if _state != HIDDEN and _state != HIDING:
			_visible_timer += 1.0 / 30.0

			if _visible_timer >= FULL_HEALTH_HIDE_DELAY:
				_state = HIDING


func _process(delta: float) -> void:
	if not is_instance_valid(_mario):
		_find_mario()
		return

	_update_power_meter_animation(delta)


func _update_power_meter_animation(delta: float) -> void:
	if not is_instance_valid(power_meter):
		return

	match _state:
		HIDDEN:
			return

		EMPHASIZED:
			# Equivalent to SM64's POWER_METER_EMPHASIZED state.
			# It remains at the starting position until the 45-frame
			# visibility logic changes the state.
			_power_meter_y = HIDDEN_Y

			if _mario.health_wedges < 8:
				_state = DEEMPHASIZING

		DEEMPHASIZING:
			var speed: float = 10.0

			if _power_meter_y > 180.0:
				speed = 5.0

			if _power_meter_y > 190.0:
				speed = 3.0

			if _power_meter_y > 195.0:
				speed = 2.0

			_power_meter_y += speed

			if _power_meter_y > VISIBLE_Y:
				_power_meter_y = VISIBLE_Y
				_state = VISIBLE

		VISIBLE:
			_power_meter_y = VISIBLE_Y

			if _mario.health_wedges < 8:
				_visible_timer = 0.0

		HIDING:
			_power_meter_y += HIDE_SPEED

			if _power_meter_y > HIDE_Y:
				_power_meter_y = HIDE_Y
				_state = HIDDEN
				_visible_timer = 0.0

	power_meter.position.y = _power_meter_y

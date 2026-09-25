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
			_mario.lives_changed.connect(_render_lives)
			_mario.coins_changed.connect(_render_coins)
			_mario.stars_changed.connect(_render_stars)
		_update_health_bar()
		return

	var mario := get_parent().get_node_or_null("LibSM64Mario") as LibSM64Mario

	if not mario:
		mario = get_tree().get_first_node_in_group("libsm64_mario") as LibSM64Mario

	if not mario:
		return

	_mario = mario
	_mario.health_wedges_changed.connect(_on_health_changed)
	_mario.lives_changed.connect(_render_lives)
	_mario.coins_changed.connect(_render_coins)
	_mario.stars_changed.connect(_render_stars)
	_update_health_bar()
	_render_lives()


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

const DIGIT_ANIMATIONS: Array[StringName] = [
	&"segment2.00000.rgba16",
	&"segment2.00200.rgba16",
	&"segment2.00400.rgba16",
	&"segment2.00600.rgba16",
	&"segment2.00800.rgba16",
	&"segment2.00A00.rgba16",
	&"segment2.00C00.rgba16",
	&"segment2.00E00.rgba16",
	&"segment2.01000.rgba16",
	&"segment2.01200.rgba16",
]

const MINUS_ANIMATION: StringName = &"segment2.02C00.rgba16"


func _render_lives() -> void:
	if not is_instance_valid(_mario):
		return

	var lives: int = _mario.lives
	var negative: bool = lives < 0
	var value: int = abs(lives)

	# LibSM64 normally won't produce huge values, but keep the HUD
	# within the three numeric character slots.
	value = min(value, 999)

	var ones: int = value % 10
	var tens: int = (value / 10) % 10
	var hundreds: int = (value / 100) % 10

	# Ones digit
	%Counter1.animation = DIGIT_ANIMATIONS[ones]
	%Counter1.frame = 0
	%Counter1.show()

	# Tens digit
	if value >= 10:
		%Counter2.animation = DIGIT_ANIMATIONS[tens]
		%Counter2.frame = 0
		%Counter2.show()
	else:
		%Counter2.hide()

	# Hundreds digit
	if value >= 100:
		%Counter3.animation = DIGIT_ANIMATIONS[hundreds]
		%Counter3.frame = 0
		%Counter3.show()
	else:
		%Counter3.hide()

	# Minus sign
	if negative:
		%Counter4.animation = MINUS_ANIMATION
		%Counter4.frame = 0
		%Counter4.show()
	else:
		%Counter4.hide()

func _render_coins() -> void:
	if not is_instance_valid(_mario):
		return

	var coins: int = _mario.coin_count
	var value: int = clamp(coins, 0, 999)

	var ones: int = value % 10
	var tens: int = (value / 10) % 10
	var hundreds: int = (value / 100) % 10

	# Coin icon
	%Coin.show()

	# X
	%XC.show()

	# Ones digit
	if value <= 10:
		%Counter1C.animation = DIGIT_ANIMATIONS[ones]
		%Counter1C.frame = 0
		%Counter1C.show()

	# Tens digit
	if value >= 10:
		%Counter1C.animation = DIGIT_ANIMATIONS[tens]
		%Counter1C.frame = 0
		%Counter1C.show()
		%Counter2C.animation = DIGIT_ANIMATIONS[ones]
		%Counter2C.frame = 0
		%Counter2C.show()
	else:
		%Counter2C.hide()

	# Hundreds digit
	if value >= 100:
		%Counter1C.animation = DIGIT_ANIMATIONS[hundreds]
		%Counter1C.frame = 0
		%Counter1C.show()
		%Counter2C.animation = DIGIT_ANIMATIONS[tens]
		%Counter2C.frame = 0
		%Counter2C.show()
		%Counter3C.animation = DIGIT_ANIMATIONS[ones]
		%Counter3C.frame = 0
		%Counter3C.show()
	else:
		%Counter3C.hide()

func _render_stars() -> void:
	if not is_instance_valid(_mario):
		return

	var stars: int = clamp(_mario.stars_collected, 0, 999)

	var ones: int = stars % 10
	var tens: int = (stars / 10) % 10
	var hundreds: int = (stars / 100) % 10

	%Star.show()

	# SM64 hides the X once the count reaches 100.
	if stars < 100:
		%XS.show()
	else:
		%XS.hide()

	# Ones digit
	%Counter1S.animation = DIGIT_ANIMATIONS[ones]
	%Counter1S.frame = 0
	%Counter1S.show()

	# Tens digit
	if stars >= 10:
		%Counter2S.animation = DIGIT_ANIMATIONS[tens]
		%Counter2S.frame = 0
		%Counter2S.show()
	else:
		%Counter2S.hide()

	# Hundreds digit
	if stars >= 100:
		%Counter3S.animation = DIGIT_ANIMATIONS[hundreds]
		%Counter3S.frame = 0
		%Counter3S.show()
	else:
		%Counter3S.hide()

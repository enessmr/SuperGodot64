extends Node3D
class_name Toad
## SM64-decomp-style Toad AI (a revived bhvToadMessage).
## Plays every FBX take except the generic "Action" ones and reacts to the
## LibSM64 Mario (point `player_path` at your mario.gd / SM64Mario node).

# --- Animations (exact import names — including the "Node" typo) ------------
const ANIM_WAVE_THEN_RUN := "ArmatureObj|0 - Wave Then Run (West)"   # one-shot, West bake only
const ANIM_WALK_WEST     := "ArmatureObj|1 - Walking (West)"
const ANIM_NOD_THEN_TURN := "ArmatureObj|2 - Node Then Turn (East)"  # one-shot, East bake only
const ANIM_WALK_EAST     := "ArmatureObj|3 - Walking (East)"
const ANIM_STAND_WEST    := "ArmatureObj|4 - Standing (West)"
const ANIM_STAND_EAST    := "ArmatureObj|5 - Standing (East)"
const ANIM_WAVE_BOTH     := "ArmatureObj|6 - Waving Both Arms (West)" # West bake only
const ANIM_WAVE_ONE      := "ArmatureObj|7 - Waving One Arm (East)"   # East bake only

const LOOPING_ANIMS: Array[String] = [
	ANIM_STAND_WEST, ANIM_STAND_EAST, ANIM_WALK_WEST, ANIM_WALK_EAST,
	ANIM_WAVE_BOTH,
]

# --- oAction-style state machine (decomp: the castle-Toad behaviour) --------
enum ToadAction {
	STANDING,  # cur_obj_init_animation_with_sound(standing); wait for Mario
	WALKING,   # pace between the two patrol points
	TURNING,   # "Nod Then Turn" at a patrol end, then flip facing
	WAVING,    # oDistanceToMario < wave_distance
	WAVE_RUN,  # Mario way too close -> Wave Then Run, then flee
	TALKING,   # Mario is in ACT_READING_NPC_DIALOG in front of us
}

# Same numeric IDs as the decomp's ACT_ table (libsm64 keeps them 1:1).
# Verify in your decomp copy:  grep -rn "ACT_READING_NPC_DIALOG" include src
const ACT_READING_NPC_DIALOG := 0x38000382
const ACT_READING_AUTOMATIC_DIALOG := 0x0C4003D7

@export var player: Node3D               ## mario.gd / SM64Mario node
@export var start_facing_west := true
@export var can_patrol := true
@export var can_run_away := true
@export var patrol_point_west := Vector3.ZERO   ## falls back to spawn position
@export var patrol_point_east := Vector3(4, 0, 0)
@export var walk_speed := 1.2
@export var run_speed := 3.4
@export var wave_distance := 10.0                ## start waving below this
@export var run_away_distance := 1.5            ## "Wave Then Run" below this
@export var model_faces_west := true            ## untick if the (West) bakes actually face east
@export var credits_wave := false

var _action: ToadAction = ToadAction.STANDING
var _facing_west := true
var _target := Vector3.ZERO
var _running := false
var _timer := 0.0
var _player: Node3D
var _visual_base_yaw := 0.0
var _warned := {}

@onready var _anim: AnimationPlayer = _find_anim_player()
@onready var _visual: Node3D = _find_visual()


func _ready() -> void:
	add_to_group("toads")
	_facing_west = start_facing_west
	if _anim == null:
		push_error("Toad: no AnimationPlayer found."); return
	if patrol_point_west.is_zero_approx():
		patrol_point_west = global_position
	if _visual:
		_visual_base_yaw = _visual.rotation.y

	# FBX takes import as non-looping; force-loop everything that must loop.
	for anim_name in LOOPING_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		elif not _warned.has(anim_name):
			_warned[anim_name] = true
			push_warning("Toad: missing animation '%s' (check FBX import names)." % anim_name)
	if not _anim.has_animation(ANIM_WAVE_THEN_RUN):
		can_run_away = false

	_anim.animation_finished.connect(_on_animation_finished)
	_enter_standing()


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _anim == null:
		return

	var to_mario := Vector2.ZERO
	var dist := INF
	var mario := _get_mario()
	if mario:
		to_mario = _flat(mario.global_position - global_position)
		dist = to_mario.length()

	# Mario is reading our dialog -> freeze, like the decomp does.
	if _mario_is_reading():
		if _action != ToadAction.TALKING:
			_enter_talking()
		_face_towards(to_mario)
		_play_stand()
		return
	elif _action == ToadAction.TALKING:
		_enter_standing()

	match _action:
		ToadAction.STANDING:
			if dist < run_away_distance and can_run_away and _timer <= 0.0:
				_enter_wave_run()
			elif dist < wave_distance:
				_enter_waving()
			elif can_patrol and _timer <= 0.0:
				_enter_walking()
		ToadAction.WALKING:
			_do_walk(delta)
		ToadAction.WAVING:
			_face_towards(to_mario)
			_play_wave()  # keeps the West/East variant in sync with facing
			if dist < run_away_distance and can_run_away and _timer <= 0.0:
				_enter_wave_run()
			elif _timer <= 0.0 and dist > wave_distance * 1.25:
				_enter_standing()
		_:
			pass  # TURNING / WAVE_RUN wait for animation_finished, TALKING is frozen


# --- State transitions -------------------------------------------------------
func _enter_standing() -> void:
	_action = ToadAction.STANDING
	_running = false
	_anim.speed_scale = 1.0
	_play_stand()
	_timer = randf_range(2.0, 6.0)  # idle pause before pacing again

func _enter_walking() -> void:
	_action = ToadAction.WALKING
	_running = false
	_anim.speed_scale = 1.0
	var d_west := absf(global_position.x - patrol_point_west.x)
	var d_east := absf(global_position.x - patrol_point_east.x)
	_target = patrol_point_east if d_west < d_east else patrol_point_west
	_facing_west = _target.x < global_position.x
	_play_walk()

func _enter_turning() -> void:
	_action = ToadAction.TURNING
	_anim.speed_scale = 1.0
	if _anim.has_animation(ANIM_NOD_THEN_TURN):
		_play_bake(ANIM_NOD_THEN_TURN, false)  # East bake only; flipped for west turns
	else:
		_facing_west = not _facing_west
		_enter_standing()

func _enter_waving() -> void:
	_action = ToadAction.WAVING
	_anim.speed_scale = 1.0
	_timer = 1.0  # minimum wave duration
	_play_wave()

func _enter_wave_run() -> void:
	_action = ToadAction.WAVE_RUN
	_anim.speed_scale = 1.0
	_play_bake(ANIM_WAVE_THEN_RUN, true)  # West bake only; flipped when facing east

func _enter_talking() -> void:
	_action = ToadAction.TALKING
	_anim.speed_scale = 1.0
	_play_stand()

func _begin_flee() -> void:
	_action = ToadAction.WALKING
	_running = true
	if can_patrol:
		var d_west := absf(global_position.x - patrol_point_west.x)
		var d_east := absf(global_position.x - patrol_point_east.x)
		_target = patrol_point_west if d_west > d_east else patrol_point_east
	else:
		var away := Vector3.RIGHT
		var mario := _get_mario()
		if mario:
			away = global_position - mario.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.RIGHT
		_target = global_position + away.normalized() * 3.0
	_facing_west = _target.x < global_position.x
	_anim.speed_scale = 1.5  # run!
	_play_walk()

func _do_walk(delta: float) -> void:
	var to_target := _target - global_position
	to_target.y = 0.0
	var speed := run_speed if _running else walk_speed
	var step := speed * delta
	if to_target.length() <= step:
		global_position = _target
		if _running or not can_patrol:
			_enter_standing()
		else:
			_enter_turning()
	else:
		global_position += to_target.normalized() * step


# --- Playback helpers --------------------------------------------------------
func _play_stand() -> void:
	_play_bake(ANIM_STAND_WEST, _facing_west)

func _play_walk() -> void:
	_play_bake(ANIM_WALK_WEST if _facing_west else ANIM_WALK_EAST, _facing_west)

func _play_wave() -> void:
	if not credits_wave:
		_play_bake(ANIM_WAVE_BOTH, _facing_west)
	elif credits_wave:
		_play_bake(ANIM_WAVE_ONE, _facing_west)

## Plays a bake and spins the model 180° when the bake faces the other way —
## the FBX only bakes some takes for one side (same trick as flipping
## oFaceAngleYaw in the decomp).
func _play_bake(bake: String, bake_is_west: bool) -> void:
	var bake_faces_west := bake_is_west if model_faces_west else (not bake_is_west)
	_visual.rotation.y = _visual_base_yaw if bake_faces_west == _facing_west else _visual_base_yaw + PI
	if _anim.current_animation == bake:
		return
	if _anim.has_animation(bake):
		_anim.play(bake)
	elif not _warned.has(bake):
		_warned[bake] = true
		push_warning("Toad: missing animation '%s'." % bake)

func _face_towards(to_mario: Vector2) -> void:
	if absf(to_mario.x) > 0.05:
		_facing_west = to_mario.x < 0.0

func _on_animation_finished(anim_name: StringName) -> void:
	match String(anim_name):
		ANIM_NOD_THEN_TURN:
			if _action == ToadAction.TURNING:
				_facing_west = not _facing_west
				_enter_standing()
		ANIM_WAVE_THEN_RUN:
			if _action == ToadAction.WAVE_RUN:
				_begin_flee()


# --- LibSM64 player access ---------------------------------------------------
func _get_mario() -> Node3D:
	if is_instance_valid(player):
		return player
	player = get_tree().get_first_node_in_group("mario") as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	return player

## True while Mario's LibSM64 action is one of the "reading" actions.
func _mario_is_reading() -> bool:
	var m := _get_mario()
	if m == null:
		return false
	var action_value: Variant = m.get("action")  # SM64Mario.action
	if action_value == null:
		return false
	var a := int(action_value)
	return a == ACT_READING_NPC_DIALOG or a == ACT_READING_AUTOMATIC_DIALOG

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func _find_anim_player() -> AnimationPlayer:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		var found := find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			ap = found[0] as AnimationPlayer
	return ap

func _find_visual() -> Node3D:
	var v := get_node_or_null("ArmatureObj") as Node3D
	if v == null:
		for child in get_children():
			if child is Node3D:
				v = child
				break
	return v if v else self


# --- Public API for your dialog system ---------------------------------------
func begin_dialog() -> void:
	_enter_talking()

func end_dialog() -> void:
	if _action == ToadAction.TALKING:
		_enter_standing()

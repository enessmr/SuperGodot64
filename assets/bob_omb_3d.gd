class_name BobOmb3D
extends CharacterBody3D
## Godot-side approximation of SM64's generic Bob-omb behavior. Native object
## pickup hooks are not exposed by this LibSM64 binding.

enum BobOmbState {
	PATROL,
	CHASE,
	EXPLODE,
	HELD,
	LAUNCHED
}

# Constants - CORRECTED VALUES
const FPS: float = 30.0
const N64_TO_GODOT: float = 0.04
const PATROL_SPEED: float = 5.0 * FPS * N64_TO_GODOT
const CHASE_SPEED: float = 20.0 * FPS * N64_TO_GODOT
const GRAVITY: float = 2.5 * FPS * FPS * N64_TO_GODOT
const FUSE_TIME: int = 151
const CHASE_RADIUS: float = 400.0 * N64_TO_GODOT
const LOSE_INTEREST_RADIUS: float = 10000.0 * N64_TO_GODOT
const PICKUP_RADIUS: float = 1.8
const FACING_ANGLE_THRESHOLD: float = TAU * 0x2000 / 65536.0
const TURN_SPEED: float = TAU * 0x800 / 65536.0 * FPS
const HOME_RETURN_DISTANCE: float = 100.0 * N64_TO_GODOT
const RETURN_DISTANCE: float = 15.0
const RETURN_TO_HOME: float = 8.0
const EXPLOSION_SCALE_FACTOR: float = 0.2
const EXPLOSION_FRAMES: int = 5
const FLOOR_AND_OBJECT_MASK: int = 1 | LibSM64SurfaceHandlerBase.OBJECT_COLLISION_LAYER
const BODY_COLLISION_LAYER: int = 2
const DEFAULT_GRAB_ACTION: StringName = &"libsm64_mario_inputs_button_b"

# Mario Action Constants
const ACT_PICKING_UP: int = 0x00000383
const ACT_DIVE_PICKING_UP: int = 0x00000385
const ACT_THROWING: int = 0x80000588
const ACT_HEAVY_THROW: int = 0x80000589
const ACT_HOLD_IDLE: int = 0x08000207
const ACT_HOLD_HEAVY_IDLE: int = 0x08000208
const ACT_HOLD_WALKING: int = 0x00000442

@export var patrol_speed: float = PATROL_SPEED
@export var chase_speed: float = CHASE_SPEED
@export var gravity: float = GRAVITY
@export var fuse_time: int = FUSE_TIME
@export var explosion_scene: PackedScene
@export var grab_action: StringName = DEFAULT_GRAB_ACTION

var state: BobOmbState = BobOmbState.PATROL
var _previous_grab_pressed: bool = false
var fuse: int = 0
var home_position: Vector3
var move_yaw: float = 0.0
var mario: LibSM64Mario
var explosion_scale: float = 1.0

var model: Node3D
var animation_player: AnimationPlayer

func _ready() -> void:
	model = get_node_or_null("Model") as Node3D
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	home_position = global_position
	find_mario()
	play_animation("0 - Walking_002")
	
	floor_snap_length = 0.25
	floor_stop_on_slope = true
	collision_layer = BODY_COLLISION_LAYER
	collision_mask = FLOOR_AND_OBJECT_MASK
	if get_node_or_null("CollisionShape3D") == null:
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 0.45
		capsule.height = 1.2
		collision_shape.shape = capsule
		add_child(collision_shape)
		collision_shape.position.y = 0.6
	if explosion_scene == null:
		explosion_scene = load("res://assets/bob_omb_explosion.tscn") as PackedScene

func _physics_process(delta: float) -> void:
	find_mario()
	
	# CRITICAL FIX: Only decrement fuse in non-patrol states
	if state != BobOmbState.PATROL and fuse > 0:
		fuse -= 1
		if fuse == 0:
			start_explosion()
	
	match state:
		BobOmbState.PATROL:
			patrol_state(delta)
		BobOmbState.CHASE:
			chase_state(delta)
		BobOmbState.EXPLODE:
			explode_state(delta)
		BobOmbState.HELD:
			held_state(delta)
		BobOmbState.LAUNCHED:
			launched_state(delta)

func patrol_state(delta: float) -> void:
	check_mario_pickup()
	if state == BobOmbState.HELD:
		return
	if mario and global_position.distance_to(mario.global_position) < CHASE_RADIUS:
		var angle_to_mario: float = calculate_angle_to_mario()
		if abs(wrapf(angle_to_mario - rotation.y, -PI, PI)) < FACING_ANGLE_THRESHOLD:
			state = BobOmbState.CHASE
			fuse = fuse_time
			return
	
	# Patrol movement
	var target_yaw: float
	if global_position.distance_to(home_position) > HOME_RETURN_DISTANCE:
		target_yaw = atan2(home_position.x - global_position.x, 
						  home_position.z - global_position.z)
	else:
		target_yaw = move_yaw + PI * 0.5 * delta
	
	move_yaw = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)
	rotation.y = move_yaw
	
	# FIXED: Proper gravity application
	velocity.x = sin(move_yaw) * patrol_speed
	velocity.z = cos(move_yaw) * patrol_speed
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	update_walk_animation()

func chase_state(delta: float) -> void:
	if not mario:
		state = BobOmbState.PATROL
		fuse = 0
		return
	
	var angle_to_mario: float = calculate_angle_to_mario()
	rotation.y = angle_to_mario
	
	velocity.x = sin(angle_to_mario) * chase_speed
	velocity.z = cos(angle_to_mario) * chase_speed
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	
	if global_position.distance_to(mario.global_position) > LOSE_INTEREST_RADIUS:
		state = BobOmbState.PATROL
		fuse = 0
	elif global_position.distance_to(home_position) < RETURN_TO_HOME:
		state = BobOmbState.PATROL
	
	update_walk_animation()

func explode_state(_delta: float) -> void:
	if animation_player and animation_player.has_animation("1 - Strugling_002"):
		if animation_player.current_animation != "1 - Strugling_002":
			animation_player.play("1 - Strugling_002")
	
	# FIXED: Proper explosion scaling
	explosion_scale = 1.0 + (float(EXPLOSION_FRAMES - fuse) * EXPLOSION_SCALE_FACTOR)
	if model:
		model.scale = Vector3.ONE * explosion_scale
	
	if fuse <= 0:
		spawn_explosion()
		queue_free()

func held_state(_delta: float) -> void:
	if not mario:
		state = BobOmbState.PATROL
		return
	
	# FIXED: Proper SM64-style held position
	var forward: Vector3 = Vector3(sin(mario.face_angle), 0.0, cos(mario.face_angle))
	
	global_position = mario.global_position + \
					 Vector3.UP * 1.5 + \
					 forward * 0.8
	rotation.y = mario.face_angle
	velocity = Vector3.ZERO
	
	if mario.action == ACT_THROWING or mario.action == ACT_HEAVY_THROW:
		state = BobOmbState.LAUNCHED
		velocity = forward * chase_speed * 1.5 + Vector3.UP * chase_speed
	elif mario.action != ACT_PICKING_UP and \
		 mario.action != ACT_DIVE_PICKING_UP and \
		 mario.action != ACT_HOLD_IDLE and \
		 mario.action != ACT_HOLD_HEAVY_IDLE and \
		 mario.action != ACT_HOLD_WALKING:
		state = BobOmbState.PATROL
		fuse = 0

func launched_state(delta: float) -> void:
	# FIXED: Proper gravity without 30x multiplier
	velocity.y -= gravity * delta
	move_and_slide()
	
	# FIXED: Explode on floor impact or timeout
	if is_on_floor() or fuse <= 0:
		state = BobOmbState.EXPLODE
		fuse = EXPLOSION_FRAMES

func check_mario_pickup() -> void:
	if not mario or not InputMap.has_action(grab_action):
		return
	var pressed: bool = Input.is_action_pressed(grab_action)
	var just_pressed: bool = pressed and not _previous_grab_pressed
	_previous_grab_pressed = pressed
	var close_enough: bool = global_position.distance_to(mario.global_position) < PICKUP_RADIUS
	var is_grab_animation: bool = mario.action == ACT_PICKING_UP or mario.action == ACT_DIVE_PICKING_UP
	if close_enough and (just_pressed or is_grab_animation):
		state = BobOmbState.HELD
		fuse = maxi(fuse, fuse_time)
		play_animation("1 - Strugling_002")

func calculate_angle_to_mario() -> float:
	if not mario:
		return 0.0
	return atan2(mario.global_position.x - global_position.x, 
				mario.global_position.z - global_position.z)

func update_walk_animation() -> void:
	if animation_player and animation_player.has_animation("0 - Walking_002"):
		if animation_player.current_animation != "0 - Walking_002":
			animation_player.play("0 - Walking_002")

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func find_mario() -> void:
	if mario == null or not is_instance_valid(mario):
		var scene_root: Node = get_tree().current_scene
		if scene_root:
			mario = scene_root.find_child("LibSM64Mario", true, false) as LibSM64Mario

func start_explosion() -> void:
	state = BobOmbState.EXPLODE
	fuse = EXPLOSION_FRAMES
	explosion_scale = 1.0

func spawn_explosion() -> void:
	if explosion_scene:
		var explosion: Node3D = explosion_scene.instantiate() as Node3D
		get_parent().add_child(explosion)
		explosion.global_position = global_position

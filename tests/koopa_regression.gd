extends Node3D

const KOOPA_SCENE = preload("res://assets/koopa.tscn")
const SHELL_SCENE = preload("res://assets/koopa_shell_popped.tscn")
var failures := 0
var checks := 0
var _floor: MeshInstance3D
var _handler: LibSM64SurfaceObjectsHandler

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _mesh_box(size: Vector3, at: Vector3, group: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	add_child(node)
	node.add_to_group(group)
	return node

func _koopa(at: Vector3, with_visual := false) -> Koopa3D:
	var koopa: Koopa3D = KOOPA_SCENE.instantiate() if with_visual else Koopa3D.new()
	koopa.position = at
	koopa.coin_scene = null
	add_child(koopa)
	koopa.set_physics_process(false)
	return koopa

func _ticks(koopa: Koopa3D, count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		koopa._physics_process(1.0 / Engine.physics_ticks_per_second)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Koopa3D.WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _has_collision_nodes(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is PhysicalBoneSimulator3D:
		return true
	for child in node.get_children(true):
		if _has_collision_nodes(child):
			return true
	return false

func _run() -> void:
	SM64RNG.reset(64)
	var level_globals := LevelGlobals.new()
	level_globals.no_music = true
	add_child(level_globals)
	# Use the actual library/handlers so tests catch missing collision bridges.
	check(LibSM64Global.load_rom_file("res://Super Mario 64 (USA).z64"), "test ROM loads")
	check(LibSM64Global.init(), "libsm64 initializes")
	_floor = _mesh_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0), "libsm64_static_surfaces")
	var static_handler := LibSM64StaticSurfacesHandler.new()
	add_child(static_handler)
	static_handler.load_static_surfaces()
	_handler = LibSM64SurfaceObjectsHandler.new()
	_handler.name = "LibSM64SurfaceObjectsHandler"
	add_child(_handler)
	var wall := _mesh_box(Vector3(1, 5, 12), Vector3(5, 2.5, 0), "libsm64_surface_objects")
	_handler.load_all_surface_objects()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not _ray(Vector3(0, 3, 0), Vector3(0, -3, 0)).is_empty(), "libsm64-only floor is visible to Godot objects")
	check(not _ray(Vector3(0, 1, 0), Vector3(10, 1, 0)).is_empty(), "libsm64-only wall is visible to Godot objects")
	_handler.unload_surface_object(wall)
	await get_tree().physics_frame
	check(_ray(Vector3(0, 1, 0), Vector3(10, 1, 0)).is_empty(), "unloading a surface removes object collision immediately")
	_handler.load_surface_object(wall)
	wall.position.x = 8
	_handler.move_surface_object_now(wall)
	await get_tree().physics_frame
	check(_ray(Vector3(0, 1, 0), Vector3(6, 1, 0)).is_empty(), "moving a libsm64 surface leaves no stale collision")
	check(not _ray(Vector3(6, 1, 0), Vector3(10, 1, 0)).is_empty(), "moving surface collision follows the registered transform")

	var koopa := _koopa(Vector3(0, 4, 0), true)
	await _ticks(koopa, 3)
	check(not koopa.race_mode and koopa.state != Koopa3D.State.RACE, "regular scene does not auto-start Koopa the Quick")
	check(absf(koopa.global_position.y) < 0.05, "Koopa stands on libsm64-only floor")
	koopa.start_race()
	check(koopa.state != Koopa3D.State.RACE_COUNTDOWN, "normal Koopa rejects race start")
	var home := koopa._home
	var max_distance := 0.0
	var max_speed := 0.0
	for i in 1200:
		await _ticks(koopa, 1)
		max_distance = maxf(max_distance, koopa.global_position.distance_to(home))
		max_speed = maxf(max_speed, koopa._forward_speed)
	check(max_speed <= 3.001, "shelled wandering stays at decomp walking speed")
	check(max_distance < 13.0, "wandering remains near home instead of running to a level corner")

	# Force a runaway state away from home: the shared helper must turn it home.
	koopa.global_position = Vector3(-20, 0, 0)
	koopa._move_yaw = -PI / 2.0
	koopa._enter(Koopa3D.State.FLEE)
	await _ticks(koopa, 240)
	check(koopa.global_position.distance_to(home) < 12.0, "fleeing far from home returns toward home")
	await _ticks(koopa, 180)
	check(koopa.state != Koopa3D.State.FLEE, "fleeing ends after Mario is out of range")

	koopa.global_position = Vector3(6, 0, 0)
	koopa._home = koopa.global_position
	koopa._move_yaw = PI / 2.0
	koopa._target_yaw = PI / 2.0
	koopa._enter(Koopa3D.State.WALK)
	await _ticks(koopa, 300)
	check(koopa.global_position.x < 7.01, "Koopa cannot walk through a libsm64 wall")

	# The shell is an interaction target during a dive, solid otherwise.
	koopa.global_position = Vector3(-5, 0, 0)
	koopa._home = koopa.global_position
	koopa._move_yaw = 0
	# Hold the shell still here to exercise the complete seek/dive sequence;
	# random launch motion is tested separately below.
	koopa.shell_pop_force = 0.0
	koopa.shell_pop_up_speed = 0.0
	koopa._pop_shell()
	var shell := koopa._shell_target
	check(shell != null and not koopa.is_shelled, "attack detaches a visible shell and changes form")
	check(koopa.state == Koopa3D.State.SLIDE and koopa._forward_speed == 20.0, "shell loss uses decomp knock-out slide")
	var saw_run := false
	var saw_dive := false
	for i in 1500:
		await _ticks(koopa, 1)
		saw_run = saw_run or koopa.state == Koopa3D.State.UNSHELLED_RUN
		saw_dive = saw_dive or koopa.state == Koopa3D.State.DIVE
		if koopa.is_shelled:
			break
	check(saw_run and saw_dive, "shellless Koopa gets up, runs, and dives for a shell")
	check(koopa.is_shelled, "Koopa reclaims the shell through collision interaction")
	await get_tree().physics_frame
	check(not is_instance_valid(shell), "reclaimed shell is deleted without stale ownership")

	var occupied: KoopaShell3D = SHELL_SCENE.instantiate()
	occupied.stationary_at_spawn = true
	occupied.position = Vector3(-10, 0, 0)
	add_child(occupied)
	occupied.set_physics_process(false)
	occupied._shell_riding = true
	check(not occupied.is_available_for_koopa() and not occupied.try_reclaim(), "ridden shell cannot be reclaimed")
	occupied._shell_riding = false
	occupied._shell_consumed = true
	check(not occupied.is_available_for_koopa(), "consumed shell cannot be targeted before queue_free")
	occupied.queue_free()

	var quick := _koopa(Vector3(-25, 0, -15))
	quick.race_mode = true
	quick.race_path = PackedVector3Array([Vector3(-25, 0, -15), Vector3(-25, 0, -10), Vector3(-25, 0, -5)])
	quick._move_yaw = 0
	quick._enter(Koopa3D.State.RACE_WAIT)
	await _ticks(quick, 120)
	check(quick.state == Koopa3D.State.RACE_WAIT and quick._forward_speed == 0.0, "KtQ waits for an explicit race start")
	quick.start_race()
	await _ticks(quick, 60)
	check(quick.state == Koopa3D.State.RACE_COUNTDOWN, "KtQ honors the 50-frame countdown at 30 Hz")
	await _ticks(quick, 900)
	check(quick.state == Koopa3D.State.RACE_DONE and quick._forward_speed == 0.0, "KtQ follows the path, decelerates, and stays finished")
	check(Koopa3D.sm64_to_world(Vector3(-2220, 204, 5520)).is_equal_approx(Vector3(-55.2, 2.04, -22.2)), "decomp race path uses the level's axis and scale conversion")
	check(koopa._players.size() == 2 and koopa._animation_frames > 1.0, "both imported animation players resolve decomp states")

	var solid_shell: KoopaShell3D = SHELL_SCENE.instantiate()
	solid_shell.stationary_at_spawn = true
	solid_shell.position = Vector3(0, 0, -15)
	add_child(solid_shell)
	check(solid_shell is MeshInstance3D and not _has_collision_nodes(solid_shell), "shell is a mesh with no bodies or collision shapes, including internal nodes")
	var native_shell_surfaces := true
	for surface in solid_shell._surface_nodes:
		native_shell_surfaces = native_shell_surfaces and surface.is_in_group("libsm64_surface_objects") and _handler.get_surface_object_id(surface) >= 0
	check(solid_shell._surface_nodes.size() == 2 and native_shell_surfaces, "shell meshes still register through the libsm64 surface-object group")
	solid_shell._set_shell_world_collision_enabled(false)
	solid_shell._set_shell_world_collision_enabled(true)
	check(not _has_collision_nodes(solid_shell), "reloading native shell surfaces never adds Godot bodies")
	var shell_walker := _koopa(Vector3(0, 0, -17))
	await _ticks(shell_walker, 2)
	check(not _has_collision_nodes(solid_shell) and solid_shell.find_children("*", "Skeleton3D", true, false).is_empty(), "shell stays free of skeletons and physical bone simulators after deferred initialization")
	shell_walker._move_yaw = 0
	shell_walker._target_yaw = 0
	shell_walker._enter(Koopa3D.State.WALK)
	var closest_shell_distance := INF
	for i in 240:
		await _ticks(shell_walker, 1)
		closest_shell_distance = minf(closest_shell_distance, shell_walker.global_position.distance_to(solid_shell.global_position))
	check(closest_shell_distance > 0.7, "shelled Koopa contacts a loose shell without a shell body")
	check(absf(solid_shell.global_position.y) < 0.05, "loose shell rests on terrain without raycasting onto itself")
	shell_walker.queue_free()
	solid_shell.queue_free()

	var launcher := _koopa(Vector3(20, 0, 20))
	launcher._pop_shell()
	var launched := launcher._shell_target
	var launch_velocity := launched.velocity
	check(is_equal_approx(Vector2(launch_velocity.x, launch_velocity.z).length(), launcher.shell_pop_force) and launch_velocity.y == launcher.shell_pop_up_speed, "popped shell receives the configured horizontal and upward impulse")
	check(launched.state == KoopaShell3D.State.THROWN and not launched.stationary_at_spawn, "popped shell enters scripted mesh movement")
	launcher.is_shelled = true
	launcher._pop_shell()
	var another_shell := launcher._shell_target
	check(not another_shell.velocity.is_equal_approx(launch_velocity), "successive shell pops use different random headings")
	another_shell.queue_free()
	var launch_position := launched.global_position
	for i in 30:
		await get_tree().physics_frame
	check(launched.global_position.distance_to(launch_position) > 0.2 and not _has_collision_nodes(launched), "random push moves the shell mesh without creating any bodies")
	for i in 800:
		await get_tree().physics_frame
	check(is_instance_valid(launched) and launched.is_available_for_koopa(), "popped shell persists after stopping for Mario or Koopa to recover")
	check(launched.state == KoopaShell3D.State.STATIONARY and Vector2(launched.velocity.x, launched.velocity.z).is_zero_approx(), "shell launch loses energy and comes to rest")
	launched.queue_free()
	launcher.queue_free()

	# Exercise the real Mario API (no invented native ids or fake setters).
	var mario := LibSM64Mario.new()
	mario.name = "LibSM64Mario"
	mario.position = Vector3(-15, 0, 10)
	add_child(mario)
	mario.set_physics_process(false)
	mario.set_process(false)
	mario.create()
	check(mario.id >= 0, "native Mario created for interaction tests")
	# Side contact recoils Mario without moving Koopa or touching Mario's health.
	var contact_target := _koopa(Vector3(-15, 0, 10))
	contact_target._mario = mario
	var contact_origin := contact_target.global_position
	for airborne in [false, true]:
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			contact_target._mario_contact_cooldown = 0.0
			mario.teleport(contact_origin + direction * 0.6)
			mario.action = LibSM64.ACT_FREEFALL if airborne else LibSM64.ACT_WALKING
			mario.flags = LibSM64.MARIO_NORMAL_CAP
			mario.velocity = -direction * 2.0
			mario.health = 0x880
			contact_target._check_mario_interaction()
			var expected_action := LibSM64.ACT_BACKWARD_AIR_KB if airborne else LibSM64.ACT_SOFT_BACKWARD_GROUND_KB
			check(mario.action == expected_action and mario.velocity.dot(direction) > 0.0 and contact_target.global_position == contact_origin and contact_target.is_shelled, "side contact recoils Mario without pushing Koopa (air=%s, direction=%s)" % [airborne, direction])
			mario.velocity = direction
			contact_target._check_mario_interaction()
			check(mario.velocity.is_equal_approx(direction), "continued contact does not restart knockback")
			var inputs := LibSM64MarioInputs.new()
			inputs.cam_look = Vector2(0, 1)
			var native_state: LibSM64MarioState
			for tick in 20:
				native_state = LibSM64.mario_tick(mario.id, inputs)[0]
			check(native_state.health == 0x880 and (native_state.position - contact_origin).dot(direction) > 0.6, "native knockback moves Mario away without damage")
	contact_target.queue_free()
	var victim := _koopa(Vector3(-15, 0, 10))
	await _ticks(victim, 2)
	victim._mario = mario
	mario.teleport(victim.global_position + Vector3.UP * 0.5)
	mario.action = LibSM64.ACT_FREEFALL
	mario.velocity = Vector3(0, -10, 0)
	victim._check_mario_interaction()
	check(not victim.is_shelled and victim.state == Koopa3D.State.SLIDE, "descending Mario stomp pops Koopa's shell")
	check(is_equal_approx(mario.velocity.y, 30.0 / (LibSM64.scale_factor * LibSM64.tick_delta_time)), "stomp converts decomp velocity into world units/second")
	victim._check_mario_interaction()
	check(victim.state != Koopa3D.State.SQUISHED, "shell-pop intangibility prevents same-frame death")
	# With no available shell, the unshelled state avoids Mario; it does not chase.
	var runner := _koopa(Vector3(-20, 0, 15))
	runner.is_shelled = false
	runner._mario = mario
	runner._move_yaw = 0
	runner._enter(Koopa3D.State.UNSHELLED_RUN)
	mario.teleport(runner.global_position + Vector3(0, 0, 1))
	for i in 60:
		runner._update_unshelled(1.0)
	check(runner._direction().dot(Vector3.BACK) < -0.9, "shellless Koopa steers away from nearby Mario")
	runner.queue_free()
	mario.teleport(victim.global_position + Vector3.UP * 0.5)

	var mario_shell := victim._shell_target
	mario_shell._mario = mario
	check(not mario_shell.try_reclaim(), "Mario has priority over shell reclaim within 200 units")
	check(not mario_shell._can_start_shell_ride(), "shell spawning cannot cancel Mario's upward stomp bounce")
	mario.teleport(mario_shell.global_position + Vector3.UP * 0.44)
	mario.action = LibSM64.ACT_IDLE
	mario.velocity = Vector3.ZERO
	mario_shell._update_riding_state()
	check(mario_shell._shell_riding and not mario_shell.is_available_for_koopa(), "Mario can ride a freshly popped shell")
	check(mario_shell.process_priority > mario.process_priority, "riding shell renders after Mario's interpolation update")
	mario_shell._apply_interpolation_setting()
	check(mario_shell.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "riding shell avoids double physics interpolation")
	# Advance render poses between physics ticks, including a rotated offset.
	var saved_offset := mario_shell.riding_offset
	mario_shell.riding_offset = Vector3(0.2, saved_offset.y, 0.3)
	var frames_match := true
	for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
		mario.global_position = Vector3(-15.0 + fraction, 0.44 + fraction, 10.0)
		mario.face_angle = fraction * PI
		mario_shell._process(1.0 / 144.0)
		var facing := Basis(Vector3.UP, mario.face_angle)
		var expected := mario.global_position + facing * mario_shell.riding_offset
		frames_match = frames_match and mario_shell.global_position.is_equal_approx(expected)
		frames_match = frames_match and mario_shell.global_basis.is_equal_approx(facing)
	check(frames_match, "shell follows every render pose and the configured local offset without a physics tick")
	mario_shell.riding_offset = saved_offset
	var spare: KoopaShell3D = SHELL_SCENE.instantiate()
	spare.stationary_at_spawn = true
	spare.position = Vector3(-18, 0, 10)
	add_child(spare)
	spare._mario = mario
	spare._update_riding_state()
	check(not spare._shell_riding, "riding one shell does not capture other shells")
	mario.action = LibSM64.ACT_IDLE
	mario_shell._update_riding_state()
	check(mario_shell._shell_consumed and mario.collision_position_offset.is_zero_approx(), "dismount consumes shell and clears Mario's collision offset")
	spare.queue_free()
	victim.coin_scene = preload("res://assets/coin.tscn")
	victim._intangible_frames = 0
	mario.teleport(victim.global_position + Vector3.UP * 0.5)
	mario.action = LibSM64.ACT_FREEFALL
	mario.velocity = Vector3(0, -10, 0)
	victim._check_mario_interaction()
	check(victim.state == Koopa3D.State.SQUISHED, "second stomp defeats shellless Koopa")
	var reward: Coin3D
	for child in get_children():
		if child is Coin3D:
			reward = child
	check(reward != null, "squishing Koopa instantiates a real Coin3D reward")
	if reward != null:
		reward.set_physics_process(false)
		check(reward.get_parent() == get_tree().current_scene and reward.owner == get_tree().current_scene, "reward is owned by the running scene, independently of Koopa")
		check(reward.hitbox_size == Vector3(2.0, 2.327, 2.0) and reward.blue_coin and not reward.yellow_coin and not reward.red_coin and reward.moving_coin, "reward keeps the requested hitbox and moving blue-coin settings")
		check(reward.sprite != null and reward.sprite.is_visible_in_tree() and reward.sprite.modulate == reward.sprite_color_3, "spawned reward has one visible blue sprite")
		check(reward.global_position.y + reward.sprite_offset_y - reward.coin_half_height > 0.0, "reward spawns with its sprite and floor probe above terrain")
		reward._physics_process(1.0 / 60.0)
		check(not reward._used and reward._velocity.y > 0.0, "reward visibly launches instead of being collected on its first frame")
		mario.teleport(Vector3(30, 0, 30))
		for i in 180:
			reward._physics_process(1.0 / 60.0)
		check(reward._spawn_collectible and reward.global_position.y > 0.9, "moving reward becomes collectible and collides with libsm64-only terrain")
		var coins_before := mario.coin_count
		mario.teleport(reward.global_position)
		reward._physics_process(1.0 / 60.0)
		check(reward._used and mario.coin_count == coins_before + 5, "spawned blue reward can be collected for five coins")

	var punched := _koopa(Vector3(-22, 0, 12))
	punched._mario = mario
	mario.teleport(punched.global_position + Vector3(0, 0.1, -0.5))
	mario.face_angle = 0
	mario.action = LibSM64.ACT_PUNCHING
	mario._flags = LibSM64.MARIO_PUNCHING
	punched._check_mario_interaction()
	check(not punched.is_shelled, "punch attack removes the shell as in the decomp attack table")
	if is_instance_valid(punched._shell_target):
		punched._shell_target.queue_free()
	punched.queue_free()

	victim.queue_free()
	await get_tree().process_frame
	if reward != null:
		check(is_instance_valid(reward) and reward.get_parent() == self, "coin survives Koopa being freed")
		reward.queue_free()
	# Simulate native Mario ticks through the apex, not just the GDScript setter.
	# This catches the old 30 m/s mistake and long-jump/held-A gravity differences.
	for incoming_action in [LibSM64.ACT_JUMP, LibSM64.ACT_DOUBLE_JUMP, LibSM64.ACT_LONG_JUMP, LibSM64.ACT_FREEFALL]:
		for held_a in [false, true]:
			var bounce_target := _koopa(Vector3(-25, 0, 20))
			bounce_target.is_shelled = false
			bounce_target._mario = mario
			mario.teleport(bounce_target.global_position + Vector3.UP * 0.5)
			mario.action = incoming_action
			mario.flags = LibSM64.MARIO_NORMAL_CAP
			mario.forward_velocity = 3.0
			mario.velocity = Vector3(3.0, -3.0, 0.0)
			bounce_target._check_mario_interaction()
			check(mario.action == LibSM64.ACT_FREEFALL and mario.velocity.x == 3.0 and mario.forward_velocity == 3.0, "stomp normalizes action %s while preserving horizontal speed (A=%s)" % [incoming_action, held_a])
			var start_y := mario.global_position.y
			var apex := start_y
			var inputs := LibSM64MarioInputs.new()
			inputs.cam_look = Vector2(0, 1)
			inputs.button_a = held_a
			for tick in 25:
				var native_state: LibSM64MarioState = LibSM64.mario_tick(mario.id, inputs)[0]
				apex = maxf(apex, native_state.position.y)
			check(apex - start_y > 1.0 and apex - start_y < 1.5, "native stomp height is bounded for action %s (A=%s): %.3f" % [incoming_action, held_a, apex - start_y])
			bounce_target.queue_free()

	mario.delete()
	mario.queue_free()
	await get_tree().process_frame

	# Load the serialized battlefield instance, including its overrides and scale,
	# and run it on the actual decomp terrain instead of the synthetic test floor.
	var battlefield: Node3D = load("res://libsm64_godot_demo/demo_scenes/bob_omb_battlefield/bob_omb_battlefield.tscn").instantiate()
	var level_koopa := battlefield.get_node("koopa") as Koopa3D
	battlefield.remove_child(level_koopa)
	battlefield.free()
	_floor.queue_free()
	_handler.unload_surface_object(wall)
	await get_tree().process_frame
	var terrain_script = load("res://libsm64_godot_demo/levels/bob_omb_battlefield/bob_omb_battlefield_surfaces.gd")
	var terrain := MeshInstance3D.new()
	terrain.mesh = terrain_script.generate_godot_mesh()
	add_child(terrain)
	LibSM64SurfaceHandlerBase.register_object_collision(terrain, terrain.mesh.get_faces(), Transform3D.IDENTITY)
	terrain_script.load_static_surfaces()
	add_child(level_koopa)
	level_koopa.set_physics_process(false)
	await _ticks(level_koopa, 600)
	check(level_koopa.is_shelled and not level_koopa.race_mode and level_koopa.shell_scene != null, "battlefield instance keeps valid shelled defaults and shell scene")
	check(level_koopa.global_position.distance_to(level_koopa._home) < 13.0 and level_koopa._grounded, "scaled battlefield Koopa walks on actual terrain near home")
	level_koopa.queue_free()

	koopa.queue_free()
	quick.queue_free()
	await get_tree().process_frame
	_handler.delete_all_surface_objects()
	LibSM64Global.terminate()
	print("KOOPA REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

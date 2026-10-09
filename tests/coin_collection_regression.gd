extends Node3D

var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	check(LibSM64Global.load_rom_file("res://Super Mario 64 (USA).z64"), "test ROM loads")
	check(LibSM64Global.init(), "libsm64 initializes")
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 1, 80)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.5
	add_child(floor_mesh)
	floor_mesh.add_to_group("libsm64_static_surfaces")
	var handler := LibSM64StaticSurfacesHandler.new()
	add_child(handler)
	handler.load_static_surfaces()
	var mario := LibSM64Mario.new()
	mario.name = "LibSM64Mario"
	add_child(mario)
	mario.set_physics_process(false)
	mario.set_process(false)
	mario.create()
	check(mario.id >= 0, "native Mario created")
	var red_count_before := CustomGlobals.red_coin_count
	var collection_sparkles: Array[AnimatedSprite3D] = []
	var collected_coins: Array[Coin3D] = []
	for color in ["yellow", "red", "blue"]:
		var coin := Coin3D.new()
		coin.yellow_coin = color == "yellow"
		coin.red_coin = color == "red"
		coin.blue_coin = color == "blue"
		coin.coin_amount = 5 if coin.blue_coin else (2 if coin.red_coin else 1)
		coin.moving_coin = coin.blue_coin
		coin.position = Vector3(-25, 2, 20)
		add_child(coin)
		coin.set_physics_process(false)
		coin._mario = mario
		coin._spawn_collectible = true
		coin._velocity = Vector3.ZERO
		mario.teleport(coin.global_position)
		var children_before := get_children()
		var coins_before := mario.coin_count
		coin._physics_process(1.0 / 60.0)
		var sparkle: AnimatedSprite3D
		for child in get_children():
			if child is AnimatedSprite3D and not children_before.has(child):
				sparkle = child
		check(coin._used and not coin.visible and not coin.sprite.is_visible_in_tree() and mario.coin_count == coins_before + coin.coin_amount, "%s pickup immediately hides the coin and awards its value" % color)
		check(sparkle != null and sparkle.is_visible_in_tree() and sparkle.is_playing() and sparkle.animation == &"sparkle" and sparkle.global_position.is_equal_approx(coin.global_position), "%s pickup plays a new visible sparkle at the coin position" % color)
		coin._physics_process(1.0 / 60.0)
		coin._use_coin()
		check(mario.coin_count == coins_before + coin.coin_amount and get_children().size() == children_before.size() + 1, "%s pickup cannot award coins or spawn sparkles twice" % color)
		if sparkle != null:
			check(not sparkle.sprite_frames.get_animation_loop(&"sparkle") and coin.sprite_frames_file_2.get_animation_loop(&"sparkle"), "pickup is one-shot without modifying shared particle animations")
			collection_sparkles.append(sparkle)
		collected_coins.append(coin)
	# Removing a collected coin must not cut off its scene-owned effect.
	collected_coins[0].queue_free()
	await get_tree().process_frame
	check(is_instance_valid(collection_sparkles[0]) and collection_sparkles[0].is_visible_in_tree(), "sparkle survives removal of its collected coin")
	await get_tree().create_timer(1.2).timeout
	var sparkles_finished := true
	for sparkle in collection_sparkles:
		sparkles_finished = sparkles_finished and not is_instance_valid(sparkle)
	check(sparkles_finished, "all collection sparkles clean themselves up after playback")
	for coin in collected_coins:
		if is_instance_valid(coin):
			coin.queue_free()
	CustomGlobals.red_coin_count = red_count_before

	mario.delete()
	mario.queue_free()
	await get_tree().process_frame
	LibSM64Global.terminate()
	print("COIN COLLECTION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

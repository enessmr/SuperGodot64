extends SceneTree

const RNG_SCRIPT: Script = preload("res://assets/sm64_rng.gd")

func _initialize() -> void:
	var rng: Node = RNG_SCRIPT.new()
	root.add_child(rng)
	var expected: Array[int] = [57460, 55882, 50550, 17711, 63470, 2530, 3991, 43823, 63385, 44122]
	rng.reset(0)
	for i: int in expected.size():
		var actual: int = rng.random_u16()
		assert(actual == expected[i], "SM64 random_u16 mismatch at draw %d: %d" % [i, actual])
	assert(rng.calls == expected.size(), "draw counter did not track outputs")
	assert(rng.random_linear_offset(30, 100) >= 30)
	assert(rng.random_linear_offset(30, 100) <= 129)
	var snapshot: Dictionary = rng.capture_state()
	var next_value: int = rng.random_u16()
	rng.restore_state(snapshot)
	assert(rng.random_u16() == next_value, "state restore did not reproduce sequence")
	print("SM64 RNG regression passed")
	quit()

extends Node

const RNG_SCRIPT: Script = preload("res://assets/sm64_rng.gd")

func test_sm64_rng_sequence_and_helpers() -> void:
	var rng: Node = RNG_SCRIPT.new()
	var expected: Array[int] = [57460, 55882, 50550, 17711, 63470, 2530, 3991, 43823, 63385, 44122]
	rng.reset(0)
	for i: int in expected.size():
		var actual: int = rng.random_u16()
		assert(actual == expected[i], "SM64 sequence mismatch at draw %d" % i)
	assert(rng.calls == expected.size(), "draw counter mismatch")
	var snapshot: Dictionary = rng.capture_state()
	var next_value: int = rng.random_u16()
	rng.restore_state(snapshot)
	assert(rng.random_u16() == next_value, "restored sequence mismatch")
	rng.reset(0)
	assert(rng.random_int_rshift(5, 4) == 5 + (57460 >> 4), "right-shift helper mismatch")
	rng.reset(0)
	var offset: int = rng.random_linear_offset(30, 100)
	assert(offset == 117, "linear offset mismatch: %d" % offset)
	assert(rng.calls == 1, "each helper must consume the expected single draw")

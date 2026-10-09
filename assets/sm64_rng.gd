extends Node
## Shared gameplay RNG: src/engine/behavior_script.c in the SM64 decomp.
## All 65,536 states can be assigned; the cycle starting at 0 has 65,114 states.
## No clock-based seeding and no automatic reset on scene changes.

var state: int = 0:
	set(value):
		state = value & 0xFFFF
var calls: int = 0


func reset(seed_value: int = 0) -> void:
	state = seed_value
	calls = 0


## Match the behavior-script SET_INT_RAND_RSHIFT operation.
func random_int_rshift(base: int, right_shift: int) -> int:
	assert(right_shift >= 0 and right_shift < 16, "right_shift must be in [0, 15]")
	return base + (random_u16() >> right_shift)


func random_u16() -> int:
	if state == 22026:
		state = 0
	var temp1: int = ((state & 0x00FF) << 8) ^ state
	state = ((temp1 & 0x00FF) << 8) + ((temp1 & 0xFF00) >> 8)
	temp1 = ((temp1 & 0x00FF) << 1) ^ state
	var temp2: int = (temp1 >> 1) ^ 0xFF80
	if (temp1 & 1) == 0:
		state = 0 if temp2 == 43605 else temp2 ^ 0x1FF4
	else:
		state = temp2 ^ 0x8180
	state &= 0xFFFF
	calls += 1
	return state


func random_float() -> float:
	return float(random_u16()) / 65536.0


func random_sign() -> int:
	# Preserve the original threshold, including its one-value asymmetry.
	return 1 if random_u16() >= 0x7FFF else -1


func random_float_range(minimum: float, maximum: float) -> float:
	return minimum + (maximum - minimum) * random_float()


func random_linear_offset(base: int, span: int) -> int:
	return base + int(span * random_float())


func advance(draw_count: int = 1) -> int:
	assert(draw_count >= 0, "RNG draw count must be nonnegative")
	for i in draw_count:
		random_u16()
	return state


func capture_state() -> Dictionary:
	return {"state": state, "calls": calls}


func restore_state(snapshot: Dictionary) -> void:
	state = int(snapshot["state"])
	calls = int(snapshot["calls"])

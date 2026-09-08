extends Node3D

var _libsm64_was_init := false

const SM64_TO_GODOT := 0.1
const FPS := 29.97
const FRAME_TIME := 1.0 / FPS

const SCALE_IN := [
	Vector3(0.0160, 0.0520, 0.0025),
	Vector3(0.1483, 0.1892, 0.0352),
	Vector3(0.4716, 0.5253, 0.1166),
	Vector3(0.8758, 0.9470, 0.2221),
	Vector3(1.2505, 1.3413, 0.3270),
	Vector3(1.4854, 1.5949, 0.4065),
	Vector3(1.2305, 1.5637, 0.4643),
	Vector3(0.9139, 1.3513, 0.5202),
	Vector3(1.0229, 1.2161, 0.5744),
	Vector3(1.1223, 1.0972, 0.6270),
	Vector3(1.0283, 0.9556, 0.6781),
	Vector3(0.9348, 1.0494, 0.7277),
	Vector3(0.9942, 1.0052, 0.7759),
	Vector3(1.0702, 0.9615, 0.8229),
	Vector3(0.9956, 0.9950, 0.8687),
	Vector3(0.9916, 1.0057, 0.9135),
	Vector3(1.0165, 0.9852, 0.9572),
	Vector3(0.9852, 1.0071, 1.0000),
	Vector3(0.9999, 0.9998, 1.0106),
	Vector3(1.0000, 1.0000, 1.0000)
]

const SCALE_OUT := [
	1.0000,
	0.9873,
	0.9514,
	0.8960,
	0.8246,
	0.7407,
	0.6480,
	0.5499,
	0.4501,
	0.3520,
	0.2593,
	0.1754,
	0.1040,
	0.0486,
	0.0128,
	0.0000
]

var logo_meshes: Array[Node3D] = []

var frame := 0
var frame_timer := 0.0
var playing := false

@export_category("Animation")
@export var play_on_ready := true


func _ready() -> void:
	if LibSM64Global.rom.is_empty():
		%RomPickerDialog.pick_rom()
	_libsm64_was_init = LibSM64Global.init()
	%LibSM64AudioStreamPlayer.play()
	logo_meshes = [
		$meshMesh0_1,
		$meshMesh1_1,
		$meshMesh2_1,
		$meshMesh3_1,
		$meshMesh4_1,
		$meshMesh5_1,
		$meshMesh6_1,
		$meshMesh7_1,
		$meshMesh14_1,
		$meshMesh13_1,
		$meshMesh8_1,
		$meshMesh9_1,
		$meshMesh10_1,
		$meshMesh11_1,
		$meshMesh12_1,
		$meshMesh15_1,
		$meshMesh16_1,
		$meshMesh17_1,
		$meshMesh18_1
	]

	print("Logo meshes: ", logo_meshes.size())

	if play_on_ready:
		play()


func _process(delta: float) -> void:
	if not playing:
		return

	frame_timer += delta

	while frame_timer >= FRAME_TIME:
		frame_timer -= FRAME_TIME
		advance_frame()


func play() -> void:
	frame = 0
	frame_timer = 0.0
	playing = true

	print("SM64 LOGO PLAY")

	apply_frame(frame)
	LibSM64.play_sound(LibSM64.SOUND_MENU_COIN_ITS_A_ME_MARIO, %Camera.global_position)

	frame += 1


func stop() -> void:
	playing = false


func advance_frame() -> void:
	if frame > 90:
		playing = false
		print("SM64 LOGO FINISHED")
		
		return

	apply_frame(frame)

	frame += 1


func apply_frame(current_frame: int) -> void:
	var current_scale: Vector3

	if current_frame < 20:
		current_scale = SCALE_IN[current_frame] * SM64_TO_GODOT

	elif current_frame < 75:
		current_scale = Vector3.ONE * SM64_TO_GODOT

	elif current_frame < 91:
		var out_frame := current_frame - 75
		current_scale = Vector3.ONE * SCALE_OUT[out_frame] * SM64_TO_GODOT

	else:
		current_scale = Vector3.ZERO

	apply_scale(current_scale)


func apply_scale(new_scale: Vector3) -> void:
	for mesh in logo_meshes:
		if is_instance_valid(mesh):
			mesh.scale = new_scale

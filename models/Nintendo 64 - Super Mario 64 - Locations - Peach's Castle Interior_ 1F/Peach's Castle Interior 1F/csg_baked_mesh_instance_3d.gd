@tool
class_name SM64PaintingRipple
extends MeshInstance3D

enum RippleTrigger {
	PROXIMITY,
	CONTINUOUS
}

enum PaintingState {
	IDLE,
	RIPPLE,
	ENTERED
}

@export_category("LibSM64")
@export var mario: Node3D

@export_category("Painting")
@export var painting_size: float = 6.11
@export var painting_width: float = 6.11
@export var painting_height: float = 6.11

@export_category("Mesh")
@export_range(2, 128, 1) var subdivisions_x: int = 16
@export_range(2, 128, 1) var subdivisions_y: int = 16

@export_category("Ripple")
@export var ripple_trigger: RippleTrigger = RippleTrigger.PROXIMITY

@export var passive_ripple_magnitude: float = 8.0
@export var passive_ripple_decay: float = 0.96
@export var passive_ripple_rate: float = 0.08
@export var passive_dispersion_factor: float = 12.0

@export var entry_ripple_magnitude: float = 25.0
@export var entry_ripple_decay: float = 0.96
@export var entry_ripple_rate: float = 0.08
@export var entry_dispersion_factor: float = 12.0

@export_category("Behavior")
@export var trigger_distance: float = 100.0
@export var entry_distance: float = 0.01
@export var auto_enter: bool = true

@export_category("Continuous Ripple")
@export var continuous_start_immediately: bool = true

@export_category("Rendering")
@export var material: Material
@export var alpha: float = 1.0

@export_category("Misc")
@export_node_path("AnimationPlayer") var anim_path: NodePath = NodePath("../../../AnimationPlayer2")
var anim: AnimationPlayer
@export var level_id_warp : int = 1
@export var _course_id := 1
@export var _course_name := "BOB-OMB BATTLEFIELD"
@export var _course_number := 1
@export var scene_to_warp := "res://libsm64_godot_demo/demo_scenes/bob_omb_battlefield/bob_omb_battlefield.tscn"
var scene_tree: SceneTree = get_tree()

const TWO_PI: float = TAU
const EDGE_TOLERANCE: float = 0.01

var state: PaintingState = PaintingState.IDLE

var curr_ripple_mag: float = 0.0
var ripple_decay: float = 1.0
var curr_ripple_rate: float = 0.0
var dispersion_factor: float = 1.0
var ripple_timer: float = 0.0

var ripple_x: float = 0.0
var ripple_y: float = 0.0

var mario_local_x: float = 0.0
var mario_local_y: float = 0.0
var mario_local_z: float = 0.0

var was_inside: bool = false
var is_inside: bool = false
var just_entered: bool = false

var was_in_entry_zone: bool = false
var is_in_entry_zone: bool = false
var just_entered_entry_zone: bool = false

var mario_stopped: bool = false

var mario_previous_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var mario_previous_visible: bool = true
var mario_previous_child_visibility: Dictionary = {}

var generated_mesh: ArrayMesh
var base_vertices: PackedVector3Array
var base_normals: PackedVector3Array
var base_uvs: PackedVector2Array
var base_indices: PackedInt32Array

var vertex_movable: PackedByteArray

var vertex_count: int = 0
var triangle_count: int = 0

var _material: Material


func _ready() -> void:
	anim = get_node_or_null(anim_path) as AnimationPlayer

	if anim == null:
		push_error(
			"SM64PaintingRipple: Could not find AnimationPlayer at "
			+ str(anim_path)
		)
	else:
		print(
			"SM64PaintingRipple: Found AnimationPlayer: ",
			anim.get_path()
		)

	if material != null:
		_material = material

	_build_base_mesh()

	if ripple_trigger == RippleTrigger.CONTINUOUS and continuous_start_immediately:
		_start_passive_ripple_center()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	entry_distance = 0.01

	if mario == null:
		return

	_update_mario_position()
	_update_painting_state()

	if state != PaintingState.IDLE:
		_update_ripple(delta)
		_rebuild_ripple_mesh()
	else:
		if generated_mesh == null:
			_build_base_mesh()


func _update_mario_position() -> void:
	if mario == null:
		return

	var mario_world_position: Vector3 = mario.global_position

	var inverse_transform: Transform3D = global_transform.affine_inverse()
	var local_position: Vector3 = inverse_transform * mario_world_position

	mario_local_x = local_position.x
	mario_local_y = local_position.y
	mario_local_z = local_position.z

	print(
		"Mario local: ",
		mario_local_x,
		", ",
		mario_local_y,
		", ",
		mario_local_z,
		" | Entry distance: ",
		entry_distance
	)


func _update_painting_state() -> void:
	was_inside = is_inside
	was_in_entry_zone = is_in_entry_zone

	var x_inside: bool = (
		mario_local_x >= -EDGE_TOLERANCE
		and mario_local_x <= painting_width + EDGE_TOLERANCE
	)

	var y_inside: bool = (
		mario_local_y >= -EDGE_TOLERANCE
		and mario_local_y <= painting_height + EDGE_TOLERANCE
	)

	var close_to_painting: bool = (
		absf(mario_local_z) <= trigger_distance
		and x_inside
		and y_inside
	)

	is_inside = close_to_painting

	just_entered = (
		is_inside
		and not was_inside
	)

	var within_entry_distance: bool = (
		absf(mario_local_z) <= entry_distance
	)

	is_in_entry_zone = (
		x_inside
		and y_inside
		and within_entry_distance
	)

	just_entered_entry_zone = (
		is_in_entry_zone
		and not was_in_entry_zone
	)

	if is_in_entry_zone:
		_stop_and_hide_mario_on_entry()
		return

	if ripple_trigger == RippleTrigger.CONTINUOUS:
		_update_continuous_state()
	else:
		_update_proximity_state()


func _update_proximity_state() -> void:
	if state == PaintingState.IDLE:
		if close_enough_for_ripple():
			if just_entered:
				_start_entry_ripple()
			else:
				_start_passive_ripple()

	elif state == PaintingState.RIPPLE:
		if auto_enter and should_enter_painting():
			_start_entry_ripple()


func _update_continuous_state() -> void:
	if state == PaintingState.IDLE:
		if is_inside:
			_start_passive_ripple_center()

	elif state == PaintingState.RIPPLE:
		if auto_enter and should_enter_painting():
			_start_entry_ripple()

	elif state == PaintingState.ENTERED:
		if curr_ripple_mag <= passive_ripple_magnitude:
			_set_passive_parameters()


func close_enough_for_ripple() -> bool:
	return (
		absf(mario_local_z) <= trigger_distance
		and mario_local_x >= -EDGE_TOLERANCE
		and mario_local_x <= painting_width + EDGE_TOLERANCE
		and mario_local_y >= -EDGE_TOLERANCE
		and mario_local_y <= painting_height + EDGE_TOLERANCE
	)


func should_enter_painting() -> bool:
	if not auto_enter:
		return false

	return (
		is_in_entry_zone
		and absf(mario_local_z) <= entry_distance
	)


func _start_passive_ripple() -> void:
	_set_passive_parameters()

	ripple_x = _nearest_quarter_x()
	ripple_y = _mario_painting_y()

	ripple_timer = 0.0
	state = PaintingState.RIPPLE


func _start_passive_ripple_center() -> void:
	_set_passive_parameters()

	ripple_x = painting_width * 0.5
	ripple_y = painting_height * 0.5

	ripple_timer = 0.0
	state = PaintingState.RIPPLE


func _start_entry_ripple() -> void:
	curr_ripple_mag = entry_ripple_magnitude
	ripple_decay = entry_ripple_decay
	curr_ripple_rate = entry_ripple_rate
	dispersion_factor = entry_dispersion_factor

	ripple_x = _nearest_quarter_x()
	ripple_y = _mario_painting_y()

	ripple_timer = 0.0
	state = PaintingState.ENTERED


func _set_passive_parameters() -> void:
	curr_ripple_mag = passive_ripple_magnitude
	ripple_decay = passive_ripple_decay
	curr_ripple_rate = passive_ripple_rate
	dispersion_factor = passive_dispersion_factor


func _nearest_quarter_x() -> float:
	if mario_local_x < painting_width / 3.0:
		return painting_width * 0.25

	if mario_local_x < painting_width * 2.0 / 3.0:
		return painting_width * 0.50

	return painting_width * 0.75


func _mario_painting_y() -> float:
	return clampf(
		mario_local_y,
		0.0,
		painting_height
	)


func _update_ripple(delta: float) -> void:
	ripple_timer += delta * 60.0

	curr_ripple_mag *= pow(
		ripple_decay,
		delta * 60.0
	)

	if ripple_trigger == RippleTrigger.PROXIMITY:
		if curr_ripple_mag <= 1.0:
			state = PaintingState.IDLE
			curr_ripple_mag = 0.0

	elif ripple_trigger == RippleTrigger.CONTINUOUS:
		if (
			state == PaintingState.ENTERED
			and curr_ripple_mag <= passive_ripple_magnitude
		):
			state = PaintingState.RIPPLE
			_set_passive_parameters()


func calculate_ripple_at_point(
	pos_x: float,
	pos_y: float
) -> float:
	var distance_x: float = pos_x - ripple_x
	var distance_y: float = pos_y - ripple_y

	var distance_to_origin: float = sqrt(
		distance_x * distance_x
		+ distance_y * distance_y
	)

	var safe_dispersion: float = maxf(
		dispersion_factor,
		0.0001
	)

	var ripple_distance: float = (
		distance_to_origin / safe_dispersion
	)

	if ripple_timer < ripple_distance:
		return 0.0

	return curr_ripple_mag * cos(
		curr_ripple_rate
		* TWO_PI
		* (ripple_timer - ripple_distance)
	)


func _build_base_mesh() -> void:
	base_vertices.clear()
	base_normals.clear()
	base_uvs.clear()
	base_indices.clear()
	vertex_movable.clear()

	var width: int = max(2, subdivisions_x)
	var height: int = max(2, subdivisions_y)

	var vertex_rows: int = height + 1
	var vertex_columns: int = width + 1

	vertex_count = vertex_rows * vertex_columns
	triangle_count = width * height * 2

	for y in range(vertex_rows):
		var fy: float = float(y) / float(height)
		var local_y: float = fy * painting_height

		for x in range(vertex_columns):
			var fx: float = float(x) / float(width)
			var local_x: float = fx * painting_width

			base_vertices.append(
				Vector3(
					local_x,
					local_y,
					0.0
				)
			)

			base_normals.append(
				Vector3(
					0.0,
					0.0,
					1.0
				)
			)

			base_uvs.append(
				Vector2(
					fx,
					1.0 - fy
				)
			)

			vertex_movable.append(1)

	for y in range(height):
		for x in range(width):
			var top_left: int = (
				y * vertex_columns + x
			)

			var top_right: int = (
				top_left + 1
			)

			var bottom_left: int = (
				(y + 1) * vertex_columns + x
			)

			var bottom_right: int = (
				bottom_left + 1
			)

			base_indices.append(top_left)
			base_indices.append(bottom_left)
			base_indices.append(top_right)

			base_indices.append(top_right)
			base_indices.append(bottom_left)
			base_indices.append(bottom_right)

	_rebuild_static_mesh()


func _rebuild_static_mesh() -> void:
	generated_mesh = ArrayMesh.new()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = base_vertices
	arrays[Mesh.ARRAY_NORMAL] = base_normals
	arrays[Mesh.ARRAY_TEX_UV] = base_uvs
	arrays[Mesh.ARRAY_INDEX] = base_indices

	generated_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	if _material != null:
		generated_mesh.surface_set_material(
			0,
			_material
		)

	mesh = generated_mesh


func _rebuild_ripple_mesh() -> void:
	if base_vertices.is_empty():
		return

	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(base_vertices.size())

	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(base_vertices.size())

	for i in range(base_vertices.size()):
		var base: Vector3 = base_vertices[i]

		var displacement: float = 0.0

		if vertex_movable[i] != 0:
			displacement = calculate_ripple_at_point(
				base.x,
				base.y
			)

		vertices[i] = Vector3(
			base.x,
			base.y,
			displacement
		)

		normals[i] = Vector3.ZERO

	_calculate_vertex_normals(
		vertices,
		normals
	)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = base_uvs
	arrays[Mesh.ARRAY_INDEX] = base_indices

	var new_mesh: ArrayMesh = ArrayMesh.new()

	new_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	if _material != null:
		new_mesh.surface_set_material(
			0,
			_material
		)

	mesh = new_mesh


func _calculate_vertex_normals(
	vertices: PackedVector3Array,
	normals: PackedVector3Array
) -> void:
	for i in range(0, base_indices.size(), 3):
		var i0: int = base_indices[i]
		var i1: int = base_indices[i + 1]
		var i2: int = base_indices[i + 2]

		var v0: Vector3 = vertices[i0]
		var v1: Vector3 = vertices[i1]
		var v2: Vector3 = vertices[i2]

		var edge_a: Vector3 = v1 - v0
		var edge_b: Vector3 = v2 - v0

		var normal: Vector3 = edge_a.cross(edge_b)

		if normal.length_squared() > 0.000001:
			normals[i0] += normal
			normals[i1] += normal
			normals[i2] += normal

	for i in range(normals.size()):
		if normals[i].length_squared() > 0.000001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3(
				0.0,
				0.0,
				1.0
			)


func reset_painting() -> void:
	restore_mario()

	state = PaintingState.IDLE

	curr_ripple_mag = 0.0
	ripple_decay = 1.0
	curr_ripple_rate = 0.0
	dispersion_factor = 1.0
	ripple_timer = 0.0

	ripple_x = painting_width * 0.5
	ripple_y = painting_height * 0.5

	was_inside = false
	is_inside = false
	just_entered = false

	was_in_entry_zone = false
	is_in_entry_zone = false
	just_entered_entry_zone = false

	_rebuild_static_mesh()


func start_ripple_at(
	local_x: float,
	local_y: float,
	entry: bool = false
) -> void:
	if entry:
		_start_entry_ripple()

		ripple_x = clampf(
			local_x,
			0.0,
			painting_width
		)

		ripple_y = clampf(
			local_y,
			0.0,
			painting_height
		)
	else:
		_start_passive_ripple()

		ripple_x = clampf(
			local_x,
			0.0,
			painting_width
		)

		ripple_y = clampf(
			local_y,
			0.0,
			painting_height
		)


func start_center_ripple() -> void:
	_start_passive_ripple_center()


func _stop_and_hide_mario_on_entry() -> void:
	if mario == null:
		return

	if mario_stopped:
		return

	var scene_tree: SceneTree = get_tree()

	if scene_tree == null:
		push_error("SM64PaintingRipple: SceneTree is NULL.")
		return

	if not is_inside_tree():
		push_error("SM64PaintingRipple: Node is not inside the SceneTree.")
		return

	mario_stopped = true

	mario_previous_process_mode = mario.process_mode
	mario_previous_visible = mario.visible

	mario_previous_child_visibility.clear()
	_save_child_visibility(mario)

	mario.process_mode = Node.PROCESS_MODE_DISABLED
	mario.visible = false
	_set_children_visible(mario, false)

	LibSM64.play_sound_global(
		LibSM64.SOUND_MENU_STAR_SOUND
	)

	await scene_tree.create_timer(0.2).timeout

	if anim != null:
		anim.play("fade_in")

	await scene_tree.create_timer(1.8).timeout

	CustomGlobals.course_id = _course_id
	CustomGlobals.course_name = _course_name
	CustomGlobals.course_number = _course_number
	CustomGlobals.scene = scene_to_warp

	LibSM64.stop_background_music(
		LibSM64.SEQ_LEVEL_INSIDE_CASTLE
	)

	var star_select_scene: PackedScene = load(
		"res://assets/star_select.tscn"
	) as PackedScene

	if star_select_scene == null:
		push_error(
			"SM64PaintingRipple: Failed to load star_select.tscn"
		)
		return

	if not scene_tree:
		push_error(
			"SM64PaintingRipple: SceneTree disappeared before scene change."
		)
		return

	scene_tree.change_scene_to_packed(star_select_scene)

func _save_child_visibility(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			mario_previous_child_visibility[child.get_path()] = child.visible

		_save_child_visibility(child)


func _set_children_visible(node: Node, value: bool) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = value

		_set_children_visible(child, value)


func restore_mario() -> void:
	if mario == null:
		return

	if not mario_stopped:
		return

	# Restore Mario's own process mode.
	mario.process_mode = mario_previous_process_mode

	# Restore Mario's own visibility.
	mario.visible = mario_previous_visible

	# Restore child visibility states.
	_restore_child_visibility(mario)

	mario_stopped = false

	print("Mario restored.")


func _restore_child_visibility(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var path: NodePath = child.get_path()

			if mario_previous_child_visibility.has(path):
				child.visible = mario_previous_child_visibility[path]

		_restore_child_visibility(child)


func should_delete_mario() -> bool:
	if mario == null:
		return false

	var x_inside: bool = (
		mario_local_x >= -EDGE_TOLERANCE
		and mario_local_x <= painting_width + EDGE_TOLERANCE
	)

	var y_inside: bool = (
		mario_local_y >= -EDGE_TOLERANCE
		and mario_local_y <= painting_height + EDGE_TOLERANCE
	)

	var z_inside: bool = (
		absf(mario_local_z) <= entry_distance
	)

	return (
		x_inside
		and y_inside
		and z_inside
	)

class_name LibSM64SurfaceObjectsHandler
extends LibSM64SurfaceHandlerBase

## Node that handles adding and updating nodes as Surface Objects for libsm64.

## Group name that contains the nodes that are part of the scene's surface objects.
@export var surface_objects_group := &"libsm64_surface_objects"
@export var interpolate: bool = true


var _surface_objects_map := {}
var _time_since_last_tick := 0.0


func _ready() -> void:
	PhysicsInterpolationSetting.apply_to(self, interpolate)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_time_since_last_tick += delta

	if _time_since_last_tick >= LibSM64.tick_delta_time:
		_update_surface_objects()

		# We don't want to update the surface objects more than once per tick.
		_time_since_last_tick = 0.0


func _update_surface_objects() -> void:
	for node in _surface_objects_map:
		var id: int = _surface_objects_map[node]
		var transform: Transform3D = node.global_transform
		var position: Vector3 = transform.origin
		var rotation: Quaternion = transform.basis.get_rotation_quaternion()
		if node.is_in_group("libsm64_surface_objects_manual_transform"):
			var manual_transform: Variant = node.get_meta("libsm64_surface_world_transform", transform)
			if manual_transform is Transform3D:
				transform = manual_transform as Transform3D
		position = transform.origin
		rotation = transform.basis.get_rotation_quaternion()
		LibSM64.surface_object_move(id, position, rotation)
		move_object_collision(node, Transform3D(Basis(rotation), position))


## Return the registered LibSM64 id for a surface node, or -1 if absent.
func get_surface_object_id(node: Node3D) -> int:
	return int(_surface_objects_map.get(node, -1))


## Move a registered surface immediately, without waiting for the next handler tick.
func move_surface_object_now(node: Node3D) -> void:
	var id: int = get_surface_object_id(node)
	if id < 0:
		return
	var transform: Transform3D = node.global_transform
	move_object_collision(node, Transform3D(transform.basis.orthonormalized(), transform.origin))
	LibSM64.surface_object_move(
		id,
		transform.origin,
		transform.basis.get_rotation_quaternion()
	)


## Move the registered surface to an explicit world transform immediately.
func move_surface_object_to(node: Node3D, world_transform: Transform3D) -> void:
	var id: int = get_surface_object_id(node)
	if id < 0:
		return
	move_object_collision(node, Transform3D(world_transform.basis.orthonormalized(), world_transform.origin))
	LibSM64.surface_object_move(
		id,
		world_transform.origin,
		world_transform.basis.get_rotation_quaternion()
	)


## Load a node as a surface object in the [code]libsm64[/code] world.
func load_surface_object(node: Node3D) -> void:
	if get_surface_object_id(node) >= 0:
		return
	var libsm64_surface_array := LibSM64SurfaceArray.new()

	var faces := get_faces_from_node(node)

	print(
		"Loading SM64 surface: ",
		node.get_path(),
		" | Faces: ",
		faces.size(),
		" | Global position: ",
		node.global_position,
		" | Global rotation: ",
		node.global_rotation,
		" | Global scale: ",
		node.global_basis.get_scale()
	)

	if faces.is_empty():
		push_error(
			"Node %s has no faces." % node.name
		)
		return

	var transform := node.global_transform
	var position := transform.origin
	var rotation := transform.basis.get_rotation_quaternion()

	var properties := find_surface_properties(node)


	for i in range(0, faces.size(), 3):
		var v1 := faces[i + 0]
		var v2 := faces[i + 1]
		var v3 := faces[i + 2]

		if properties:
			libsm64_surface_array.add_triangle_with_properties(
				v1,
				v2,
				v3,
				properties
			)
		else:
			libsm64_surface_array.add_triangle(
				v1,
				v2,
				v3
			)

	var surface_object_id := LibSM64.surface_object_create(
		position,
		rotation,
		libsm64_surface_array
	)

	_surface_objects_map[node] = surface_object_id
	# libsm64 surface objects use position/rotation, without the node's scale.
	register_object_collision(node, faces, Transform3D(Basis(rotation), position))

	# Clean up automatically if Node3D is removed from tree or freed.
	var cleanup := delete_surface_object.bind(node)
	if not node.tree_exiting.is_connected(cleanup):
		node.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)


## Load all nodes in the [member surface_objects_group] as surface objects in the [code]libsm64[/code] world.
func load_all_surface_objects() -> void:
	var surfaces := get_tree().get_nodes_in_group(surface_objects_group)

	for node in surfaces:
		var node_3d := node as Node3D

		if not node_3d:
			push_warning(
				"Non Node3D in %s group: %s"
				% [surface_objects_group, node]
			)
			continue

		load_surface_object(node_3d)


## Remove a registered surface while preserving its local node and visual.
func unload_surface_object(node_3d: Node3D) -> void:
	disable_object_collision(node_3d)
	var id: int = get_surface_object_id(node_3d)
	if id < 0:
		return
	LibSM64.surface_object_delete(id)
	_surface_objects_map.erase(node_3d)


## Delete a surface object created from the given [param node_3d] from the [code]libsm64[/code] world if present.
func delete_surface_object(node_3d: Node3D) -> void:
	disable_object_collision(node_3d)
	var id: int = get_surface_object_id(node_3d)
	if id < 0:
		return
	LibSM64.surface_object_delete(id)
	_surface_objects_map.erase(node_3d)


## Delete all surface objects from the [code]libsm64[/code] world.
func delete_all_surface_objects() -> void:
	for node in _surface_objects_map:
		disable_object_collision(node)
	for id in _surface_objects_map.values():
		LibSM64.surface_object_delete(id)

	_surface_objects_map.clear()

	print("Deleted all SM64 surface objects.")

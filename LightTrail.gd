extends Node3D

@export var trail_color: Color = Color("bf7fbf")
@export var trail_height: float = 1.0
@export var min_point_distance: float = 0.15
@export var max_points: int = 400
@export var action: String = "ui_select"
@export var ground_y: float = 0.0

var _active: bool = false
var _points: Array[Vector3] = []
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = trail_color
	_material.emission_enabled = true
	_material.emission = trail_color
	_material.emission_energy_multiplier = 3.0
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_mesh_instance)


func _process(_delta: float) -> void:
	var was_active := _active
	_active = Input.is_action_pressed(action)

	if was_active and not _active:
		_points.clear()
		_mesh_instance.mesh = null
		return

	if not _active:
		return

	var wp := Vector3(global_position.x, ground_y, global_position.z)

	if _points.is_empty() or wp.distance_to(_points[-1]) >= min_point_distance:
		_points.append(wp)
		if _points.size() > max_points:
			_points.pop_front()
		_rebuild_mesh()


func _rebuild_mesh() -> void:
	if _points.size() < 2:
		return

	var verts  := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(_points.size()):
		var b := _points[i]
		var t := b + Vector3.UP * trail_height
		verts.append(b)   # bottom  index i*2
		verts.append(t)   # top     index i*2+1
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

	for i in range(_points.size() - 1):
		var b0 := i * 2
		var t0 := i * 2 + 1
		var b1 := (i + 1) * 2
		var t1 := (i + 1) * 2 + 1
		# Tri 1
		indices.append(b0)
		indices.append(t0)
		indices.append(b1)
		# Tri 2
		indices.append(t0)
		indices.append(t1)
		indices.append(b1)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh


func _exit_tree() -> void:
	if is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()

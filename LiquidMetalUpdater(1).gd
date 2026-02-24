extends Node

@export var bike: NodePath
@export var ground_mesh: NodePath
@export var wheel_track_width: float = 0.6

enum RightAxis { POS_X, NEG_X, POS_Z, NEG_Z }
@export var right_axis: RightAxis = RightAxis.POS_X



var _bike_node: CharacterBody3D
var _mesh_node: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_bike_node = get_node(bike)
	_mesh_node = get_node(ground_mesh)
	_material  = _mesh_node.get_active_material(0) as ShaderMaterial


func _process(_delta: float) -> void:
	if not is_instance_valid(_bike_node) or not is_instance_valid(_material):
		return

	var vel := _bike_node.velocity
	var speed := Vector2(vel.x, vel.z).length()
	var top_speed: float = _bike_node.get("top_speed") if _bike_node.get("top_speed") else 14.0
	var speed_n := clampf(speed / top_speed, 0.0, 1.0)

	# Normalized flat velocity direction
	var vel_dir := Vector3(vel.x, 0.0, vel.z).normalized()

	# Offset wheel origins slightly behind the bike so ripples trail behind
	var trail_offset := -vel_dir * 0.8

	var right := _get_right()
	var half  := right * (wheel_track_width * 0.5)

	var left_pos  := _bike_node.global_position + trail_offset - half
	var right_pos := _bike_node.global_position + trail_offset + half

	_material.set_shader_parameter("wheel_left",   left_pos)
	_material.set_shader_parameter("wheel_right",  right_pos)
	_material.set_shader_parameter("bike_speed",   speed_n)
	_material.set_shader_parameter("bike_forward", vel_dir)


func _get_right() -> Vector3:
	match right_axis:
		RightAxis.POS_X: return  _bike_node.global_transform.basis.x
		RightAxis.NEG_X: return -_bike_node.global_transform.basis.x
		RightAxis.POS_Z: return  _bike_node.global_transform.basis.z
		RightAxis.NEG_Z: return -_bike_node.global_transform.basis.z
	return _bike_node.global_transform.basis.x

extends MeshInstance3D

@export var bike: CharacterBody3D

var _material: ShaderMaterial

func _ready() -> void:
	_material = get_active_material(0) as ShaderMaterial

func _process(_delta: float) -> void:
	if not is_instance_valid(bike) or not is_instance_valid(_material):
		return
	
	var speed := Vector2(bike.velocity.x, bike.velocity.z).length()
	var top_speed: float = bike.get("top_speed") if bike.get("top_speed") else 14.0
	
	_material.set_shader_parameter("bike_position", bike.global_position)
	_material.set_shader_parameter("bike_speed_normalized", clampf(speed / top_speed, 0.0, 1.0))

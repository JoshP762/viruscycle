extends MeshInstance3D

@export var rotation_speed: Vector3 = Vector3(0, 0.5, 0)  # Y axis by default

func _process(delta: float) -> void:
	rotate_x(rotation_speed.x * delta)
	rotate_y(rotation_speed.y * delta)
	rotate_z(rotation_speed.z * delta)

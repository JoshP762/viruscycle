extends Node3D

## Door.gd
## Attach to the Node3D/MeshInstance3D that acts as the door.
## Set key_id to match the key that opens it.

@export var key_id: String = "key_a"

func _ready() -> void:
	add_to_group("door_" + key_id)

func open() -> void:
	queue_free()

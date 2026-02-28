extends Area3D

## Key.gd
## Attach to an Area3D with a CollisionShape3D and MeshInstance3D.
## Set key_id to match the door it unlocks.

@export var key_id: String = "key_a"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# Tell all doors with matching ID to open
		get_tree().call_group("door_" + key_id, "open")
		queue_free()

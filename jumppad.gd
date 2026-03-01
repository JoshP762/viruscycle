extends Area3D

@export var launch_force: float = 30.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.launch(launch_force)

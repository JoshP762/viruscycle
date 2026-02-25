extends Area3D

@export var speed: float = 80.0
@export var lifetime: float = 3.0
@export var damage: int = 1

var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(dir: Vector3) -> void:
	_velocity = dir.normalized() * speed


func _process(delta: float) -> void:
	global_position += _velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

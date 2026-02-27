extends StaticBody3D

@export var missile_scene: PackedScene
@export var fire_rate: float = 3.0        # Missiles are slow and menacing
@export var detection_radius: float = 40.0  # Detects from further away
@export var missile_spawn: NodePath

@export_group("Health")
@export var max_health: int = 50
var health: int = max_health

var _player: Node3D = null
var _fire_timer: float = 0.0
var _spawn_node: Node3D
var _dead: bool = false


func _ready() -> void:
	health = max_health

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	if missile_spawn:
		_spawn_node = get_node(missile_spawn)


func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	health = clampi(health, 0, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


func _process(delta: float) -> void:
	if _dead or not is_instance_valid(_player):
		return

	# Face player
	var target := _player.global_position
	target.y = global_position.y
	look_at(target, Vector3.UP)
	rotate_y(deg_to_rad(90))

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_rate
		_shoot()


func _shoot() -> void:
	if not missile_scene:
		return
	var spawn := _spawn_node if is_instance_valid(_spawn_node) else self
	var missile := missile_scene.instantiate()
	get_tree().current_scene.add_child(missile)
	missile.global_position = spawn.global_position
	missile.setup(_player)

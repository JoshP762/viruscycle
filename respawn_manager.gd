extends Node

## RespawnManager.gd
## Attach to any node in your main scene.
## Handles player death, brief pause, then respawn at nearest checkpoint.

@export var bike: NodePath
@export var respawn_delay: float = 2.0

## Add Marker3D nodes to your scene and put them here as checkpoints.
## The nearest one to where you died will be used.
@export var checkpoints: Array[NodePath] = []

var _bike_node: CharacterBody3D
var _is_dead: bool = false


func _ready() -> void:
	if bike:
		_bike_node = get_node(bike)
		_bike_node.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	_bike_node.set_physics_process(false)
	_bike_node.set_process_input(false)


func _respawn() -> void:
	# Find nearest checkpoint to where the player died
	var spawn_pos := _get_nearest_checkpoint()

	# Reset position and velocity
	_bike_node.global_position = spawn_pos
	_bike_node.velocity = Vector3.ZERO

	# Restore health
	_bike_node.health = _bike_node.max_health
	_bike_node.health_changed.emit(_bike_node.health)

	# Unfreeze
	_bike_node.set_physics_process(true)
	_bike_node.set_process_input(true)

	_is_dead = false


func _get_nearest_checkpoint() -> Vector3:
	if checkpoints.is_empty():
		# No checkpoints set — just respawn in place slightly above ground
		return _bike_node.global_position + Vector3.UP * 2.0

	var nearest_pos := _bike_node.global_position
	var nearest_dist := INF

	for cp_path in checkpoints:
		var cp := get_node(cp_path)
		if not is_instance_valid(cp):
			continue
		var d := _bike_node.global_position.distance_to(cp.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_pos = cp.global_position

	return nearest_pos

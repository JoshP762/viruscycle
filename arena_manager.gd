extends Node3D

## ArenaManager.gd
## Add to a Node3D in your arena. Assign all enemy nodes to the enemies array.
## When all are dead, spawns the key at key_spawn_position.

@export var key_scene: PackedScene
@export var key_spawn: NodePath  # Point the key appears at — use a Marker3D
@export var enemies: Array[NodePath] = []

var _enemy_nodes: Array[Node3D] = []
var _alive: int = 0


func _ready() -> void:
	for path in enemies:
		var e := get_node(path)
		if is_instance_valid(e):
			_enemy_nodes.append(e)
			_alive += 1
			# Connect to whatever signal the enemy emits on death
			if e.has_signal("died"):
				e.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_spawn_key()


func _spawn_key() -> void:
	if not key_scene:
		return
	var spawn := get_node_or_null(key_spawn)
	var pos := global_position
	if is_instance_valid(spawn):
		pos = spawn.global_position
	var key := key_scene.instantiate()
	get_tree().current_scene.add_child(key)
	key.global_position = pos

extends Node3D

## ArenaManager.gd
## Add to a Node3D in your arena. Assign all enemy nodes to the enemies array.
## When all are dead, spawns the key at key_spawn_position.

@export var key_scene: PackedScene
@export var key_spawn: NodePath  # Point the key appears at — use a Marker3D
@export var enemies: Array[NodePath] = []

var _cleared: bool = false


signal arena_cleared

var _enemy_nodes: Array[Node3D] = []
var _alive: int = 0


func _ready() -> void:
	print("----- ARENA START -----")
	for path in enemies:
		print("Checking path:", path)
		var e := get_node_or_null(path)
		if e == null:
			print("FAILED to find:", path)
		else:
			print("Found:", e.name)
			_enemy_nodes.append(e)
			_alive += 1
			if e.has_signal("died"):
				e.died.connect(_on_enemy_died)

	print("TOTAL COUNTED:", _alive)


func _on_enemy_died() -> void:
	if _cleared:
		return

	_alive -= 1
	print("Enemy died. Remaining:", _alive)

	if _alive <= 0:
		_cleared = true
		_spawn_key()

func _spawn_key() -> void:
	arena_cleared.emit()  
	if not key_scene:
		return
	var spawn := get_node_or_null(key_spawn)
	var pos := global_position
	if is_instance_valid(spawn):
		pos = spawn.global_position
	var key := key_scene.instantiate()
	get_tree().current_scene.add_child(key)
	key.global_position = pos

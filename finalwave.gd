extends Node3D

## WaveSpawner.gd
## Attach to a Node3D. Add all second wave nodes as children (hidden by default).
## Call activate() to reveal them all at once.
## Add to group "wave2" so BossBike can trigger it.

@export var nodes_to_reveal: Array[NodePath] = []


func _ready() -> void:
	add_to_group("wave2")
	for path in nodes_to_reveal:
		var n := get_node_or_null(path)
		if is_instance_valid(n):
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED


func activate() -> void:
	for path in nodes_to_reveal:
		var n := get_node_or_null(path)
		if is_instance_valid(n):
			n.visible = true
			n.process_mode = Node.PROCESS_MODE_INHERIT

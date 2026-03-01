extends Node3D

@export var arena_manager: NodePath
@export var unlocked_color: Color = Color(0.0, 0.576, 0.83, 1.0)

func _ready() -> void:
	var manager := get_node(arena_manager)
	manager.connect("arena_cleared", _on_arena_cleared)

func _on_arena_cleared() -> void:
	# Apply to all MeshInstance3D children
	for child in get_children():
		if child is MeshInstance3D:
			var mat := child.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_color = unlocked_color
				mat.emission = unlocked_color

extends Control

@export var player: Node3D
@onready var compass_arrow = $CompassArrow

func _process(delta):
	if player == null:
		return
	
	var yaw = player.global_rotation.y
	compass_arrow.rotation = -yaw - PI / 2

extends TextureRect

@onready var speed_fill := $SpeedFill

@export var fill_rate : float = 1.5
@export var drain_rate : float = 1.0

var current_fill : float = 0.0


func _process(delta):

	if Input.is_action_pressed("input_up"):
		current_fill += fill_rate * delta
	else:
		current_fill -= drain_rate * delta

	current_fill = clamp(current_fill, 0.0, 1.0)

	speed_fill.material.set_shader_parameter("fill_amount", current_fill)

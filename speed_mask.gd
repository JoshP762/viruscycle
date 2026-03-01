extends TextureRect

@onready var speed_fill := $SpeedFill
@onready var boost_icon := $"../BoostIcon"


@export var fill_rate : float = 1.5
@export var drain_rate : float = 1.0
@export var smoothing_speed : float = 6.0

var current_fill : float = 0.0
var target_fill : float = 0.0

@export var pulse_speed : float = 4.0
var pulse_time : float = 0.0

func _ready():
	boost_icon.visible = false
	
func _process(delta):

	# Decide what the fill SHOULD be doing
	if Input.is_action_pressed("input_up"):
		target_fill += fill_rate * delta
	else:
		target_fill -= drain_rate * delta

	target_fill = clamp(target_fill, 0.0, 1.0)

	# Smoothly move current toward target
	current_fill = lerp(current_fill, target_fill, smoothing_speed * delta)
	var base_blue = Color(0.216, 0.273, 1.0, 1.0)
	var bright_blue = Color(0.2, 0.9, 1.0)
	
	var dynamic_color = base_blue.lerp(bright_blue, current_fill)

	speed_fill.material.set_shader_parameter("fill_color", dynamic_color)
	speed_fill.material.set_shader_parameter("fill_amount", current_fill)
	
	# -------- Boost Toggle --------
	if Input.is_action_just_pressed("trail_toggle"):
		boost_icon.visible = !boost_icon.visible


	# -------- Boost Pulse --------
	if boost_icon.visible:
		pulse_time += delta * pulse_speed

		var pulse_value = 0.5 + 0.5 * sin(pulse_time)  # 0 → 1 smooth

		var pink_base = Color(0.671, 0.003, 0.965, 1.0)
		var pink_bright = Color(1.0, 0.5, 0.8)

		boost_icon.modulate = pink_base.lerp(pink_bright, pulse_value)

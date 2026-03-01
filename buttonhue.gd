extends Button

var _base_scale := Vector2.ONE
var _time := 0.0
@export var streak_speed: float = 2.0
@export var streak_offset: float = 0.0  # Offset so buttons aren't in sync

func _ready() -> void:
	_base_scale = scale
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)

func _process(delta: float) -> void:
	_time += delta
	# Subtle upward drift
	var drift := sin((_time + streak_offset) * streak_speed) * 2.0
	position.y = _base_scale.y + drift

func _on_hover() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)

func _on_exit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

extends StaticBody3D

@export var max_health: int = 50
var health: int = max_health
var _dead: bool = false
@export var death_sound: AudioStream
@export var cutscene_scene: String = "res://cutscene_outro.tscn"
@export var delay: float = 5.0

signal died


func _ready() -> void:
	health = max_health


func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	health = clampi(health, 0, max_health)
	if health <= 0:
		_dead = true
		died.emit()
		_trigger_ending()

func _trigger_ending() -> void:
	if death_sound:
		var sfx := AudioStreamPlayer3D.new()
		get_tree().current_scene.add_child(sfx)
		sfx.global_position = global_position
		sfx.stream = death_sound
		sfx.play()

	await get_tree().create_timer(delay).timeout

	# Fade to black before transitioning
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	canvas.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_SINE)
	await tween.finished

	TransitionManager.goto(cutscene_scene)

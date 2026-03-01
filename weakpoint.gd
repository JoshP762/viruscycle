extends StaticBody3D

@export var max_health: int = 50
var health: int = max_health
@export var death_sound: AudioStream

var _dead: bool = false

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
		if death_sound:
			var sfx := AudioStreamPlayer3D.new()
			get_tree().current_scene.add_child(sfx)
			sfx.global_position = global_position
			sfx.stream = death_sound
			sfx.play()
			await sfx.finished
			sfx.queue_free()
		queue_free()

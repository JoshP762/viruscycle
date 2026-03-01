extends StaticBody3D

@export var max_health: int = 50
var health: int = max_health
@export var death_sound: AudioStream

signal died


func _ready() -> void:
	health = max_health

func take_damage(amount: int) -> void:
	health -= amount
	health = clampi(health, 0, max_health)
	if health <= 0:
		died.emit()  # Fire immediately so ArenaManager counts it
		if death_sound:
			var sfx := AudioStreamPlayer3D.new()
			get_tree().current_scene.add_child(sfx)
			sfx.global_position = global_position
			sfx.stream = death_sound
			sfx.play()
			await sfx.finished
			sfx.queue_free()
		queue_free()

extends Area3D

@export var key_id: String = "key_a"
@export var pickup_sound: AudioStream

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Play spawn sound
	if pickup_sound:
		var sfx := AudioStreamPlayer3D.new()
		add_child(sfx)
		sfx.stream = pickup_sound
		sfx.play()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# Play pickup sound then free
		if pickup_sound:
			var sfx := AudioStreamPlayer3D.new()
			get_tree().current_scene.add_child(sfx)
			sfx.global_position = global_position
			sfx.stream = pickup_sound
			sfx.play()
			await sfx.finished
			sfx.queue_free()
		get_tree().call_group("door_" + key_id, "open")
		queue_free()

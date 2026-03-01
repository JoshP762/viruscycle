extends Area3D

@export var music: AudioStream
@export var fade_time: float = 1.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var mm := get_tree().get_first_node_in_group("music_manager")
		if mm:
			mm.play_track(music, fade_time)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		var mm := get_tree().get_first_node_in_group("music_manager")
		if mm:
			mm.play_track(null, fade_time)

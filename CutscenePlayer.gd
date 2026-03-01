extends Node

@export var video_player: NodePath
@export var next_scene: String = "res://main.tscn"
@export var music: AudioStream

var _video: VideoStreamPlayer
var _music: AudioStreamPlayer


func _ready() -> void:
	_video = get_node(video_player)
	_video.finished.connect(_on_video_finished)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if music:
		_music = AudioStreamPlayer.new()
		add_child(_music)
		_music.stream = music
		_music.volume_db = -40.0
		_music.play()
		var tween := create_tween()
		tween.tween_property(_music, "volume_db", 0.0, 2.0)\
			.set_trans(Tween.TRANS_SINE)

	_video.play()


func _on_video_finished() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	TransitionManager.goto(next_scene)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_video.stop()
		_on_video_finished()

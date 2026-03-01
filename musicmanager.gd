extends Node3D

@export var ambient_track: AudioStream
var _player: AudioStreamPlayer
var _default_stream: AudioStream


func _ready() -> void:
	add_to_group("music_manager")

	_player = AudioStreamPlayer.new()
	add_child(_player)

	if not ambient_track:
		push_error("MusicManager: ambient_track not set")
		return

	_default_stream = ambient_track
	_player.stream = ambient_track
	_player.volume_db = -40.0
	_player.play()
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", 0.0, 2.0).set_trans(Tween.TRANS_SINE)


func play_track(new_track: AudioStream, fade: float = 1.5) -> void:
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", -40.0, fade).set_trans(Tween.TRANS_SINE)
	await tween.finished

	if new_track:
		_player.stream = new_track
	else:
		_player.stream = _default_stream

	_player.volume_db = -40.0
	_player.play()

	tween = create_tween()
	tween.tween_property(_player, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)

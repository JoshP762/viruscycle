extends Node

@export var video_player: NodePath
@export var music: AudioStream
@export var main_menu_scene: String = "res://main_menu.tscn"

var _video: VideoStreamPlayer
var _music_player: AudioStreamPlayer
var _button_shown: bool = false


func _ready() -> void:
	# Fade in from black
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 1)
	canvas.add_child(overlay)
	var fade_tween := create_tween()
	fade_tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 1.5)\
		.set_trans(Tween.TRANS_SINE)
	await fade_tween.finished
	canvas.queue_free()

	# Setup video
	_video = get_node(video_player)
	_video.finished.connect(_on_video_finished)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Setup music
	if music:
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
		_music_player.stream = music
		_music_player.volume_db = -40.0
		_music_player.play()
		var music_tween := create_tween()
		music_tween.tween_property(_music_player, "volume_db", 0.0, 2.0)\
			.set_trans(Tween.TRANS_SINE)

	_video.play()


func _on_video_finished() -> void:
	_show_menu_button()


func _show_menu_button() -> void:
	if _button_shown:
		return
	_button_shown = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Fade music out
	if is_instance_valid(_music_player):
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, 2.0)\
			.set_trans(Tween.TRANS_SINE)

	# Build button overlay
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var btn := Button.new()
	btn.text = "RETURN TO MAIN MENU"
	btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn.offset_top = -80
	btn.offset_bottom = -20
	btn.offset_left = -150
	btn.offset_right = 150
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_menu_pressed)
	canvas.add_child(btn)

	# Fade button in
	btn.modulate = Color(1, 1, 1, 0)
	var btn_tween := create_tween()
	btn_tween.tween_property(btn, "modulate", Color(1, 1, 1, 1), 1.0)\
		.set_trans(Tween.TRANS_SINE)


func _on_menu_pressed() -> void:
	TransitionManager.goto(main_menu_scene)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_video.stop()
		_on_video_finished()

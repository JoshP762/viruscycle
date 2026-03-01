extends Control

@export var menu_music: AudioStream
@export var credits_text: String = "A game by [Your Name]"  # Edit this

@onready var _video: VideoStreamPlayer = $VideoStreamPlayer
@onready var _music: AudioStreamPlayer = $AudioStreamPlayer

@export var start_sound: AudioStream


func _ready() -> void:
	# Start invisible and silent
	modulate = Color(1, 1, 1, 0)
	
	# Loop video
	_video.finished.connect(_on_video_finished)
	_video.play()

	# Start music at 0 volume
	if menu_music:
		_music.stream = menu_music
		_music.volume_db = -40.0
		_music.play()

	# Fade in everything
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 2.0)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_music, "volume_db", 0.0, 3.0)\
		.set_trans(Tween.TRANS_SINE)

func _on_video_finished() -> void:
	_video.play()


func _on_start_pressed() -> void:
	if start_sound:
		var sfx := AudioStreamPlayer.new()
		add_child(sfx)
		sfx.stream = start_sound
		sfx.play()

	await get_tree().create_timer(4.0).timeout

	# Fade music and screen out together
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music, "volume_db", -40.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.5).set_trans(Tween.TRANS_SINE)
	await tween.finished

	_music.stop()
	TransitionManager.goto("res://cutscene_intro.tscn")
	
	
func _on_credits_pressed() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 500)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var names := Label.new()
	names.text = "\nJackson Bullard\nProgramming, 3D_Modeling, Game_Design\n\nJoshua_Panasa\nProgramming, 3D_Modeling, Game_Design\n\n Sesugh_Tardzer\nProgramming, 3D_Modeling, Game_Design, Illustrations"  # Edit this
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(names)

	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(panel.queue_free)
	vbox.add_child(close)

	# Animate in
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.3)


func _on_quit_pressed() -> void:
	get_tree().quit()

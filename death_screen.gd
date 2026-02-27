extends CanvasLayer

## DeathScreen.gd
## Attach to a CanvasLayer in your main scene.
## Connect your bike's player_died signal and the RespawnManager here.

@export var bike: NodePath
@export var respawn_manager: NodePath

signal respawn_requested

var _bike_node: CharacterBody3D
var _respawn_node: Node
var _overlay: Control


func _ready() -> void:
	if bike:
		_bike_node = get_node(bike)
		_bike_node.player_died.connect(_on_player_died)
	if respawn_manager:
		_respawn_node = get_node(respawn_manager)

	_build_screen()
	_overlay.visible = false


func _build_screen() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Dark translucent background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.02, 0.82)
	_overlay.add_child(bg)

	# Scanline effect — thin horizontal lines
	for i in range(0, 1080, 4):
		var line := ColorRect.new()
		line.set_anchor(SIDE_LEFT, 0.0)
		line.set_anchor(SIDE_RIGHT, 1.0)
		line.offset_top = i
		line.offset_bottom = i + 1
		line.color = Color(0.0, 0.0, 0.0, 0.18)
		bg.add_child(line)

	# Center container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical   = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	_overlay.add_child(center)

	# "DEREZZED" title
	var title := Label.new()
	title.text = "DEREZZED"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "connection lost"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)

	# Respawn button
	var btn := Button.new()
	btn.text = "REINITIALIZE"
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.05))

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.0, 0.85, 1.0, 1.0)
	btn_normal.corner_radius_top_left     = 3
	btn_normal.corner_radius_top_right    = 3
	btn_normal.corner_radius_bottom_left  = 3
	btn_normal.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 1.0, 1.0, 1.0)
	btn_hover.corner_radius_top_left     = 3
	btn_hover.corner_radius_top_right    = 3
	btn_hover.corner_radius_bottom_left  = 3
	btn_hover.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.0, 0.5, 0.7, 1.0)
	btn_pressed.corner_radius_top_left     = 3
	btn_pressed.corner_radius_top_right    = 3
	btn_pressed.corner_radius_bottom_left  = 3
	btn_pressed.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("pressed", btn_pressed)

	btn.pressed.connect(_on_respawn_pressed)
	center.add_child(btn)

	# Animate title in with a tween on show
	_overlay.set_meta("title", title)
	_overlay.set_meta("center", center)


func _on_player_died() -> void:
	_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Animate in
	var title  := _overlay.get_meta("title")  as Label
	var center := _overlay.get_meta("center") as Control

	title.modulate = Color(1, 1, 1, 0)
	center.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(center, "modulate", Color(1, 1, 1, 1), 0.6)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(title, "modulate", Color(1, 1, 1, 1), 0.4)\
		.set_trans(Tween.TRANS_SINE)


func _on_respawn_pressed() -> void:
	_overlay.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if is_instance_valid(_respawn_node):
		_respawn_node._respawn()

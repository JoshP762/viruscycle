extends CanvasLayer

## HUD.gd
## Attach to a CanvasLayer node. Connect your bike's signals in _ready.
## Displays a Y2K-style health bar.

@export var bike: NodePath

var _bike_node: CharacterBody3D
var _health_bar: TextureProgressBar
var _health_label: Label
var _container: Control
var _flash_tween: Tween


func _ready() -> void:
	if bike:
		_bike_node = get_node(bike)
		_bike_node.health_changed.connect(_on_health_changed)
		_bike_node.player_died.connect(_on_player_died)

	_build_hud()
	print("HUD READY")


func _build_hud() -> void:
	# Root container — bottom left
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_container.position = Vector2(24, -24)
	_container.set_offset(SIDE_LEFT, 0)
	_container.set_offset(SIDE_TOP, 0)
	add_child(_container)

	# Label — "HULL" in Y2K style
	var label_row := HBoxContainer.new()
	label_row.position = Vector2(0, -48)
	_container.add_child(label_row)

	_health_label = Label.new()
	_health_label.text = "HULL  50 / 50"
	_health_label.add_theme_font_size_override("font_size", 11)
	_health_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0, 0.9))
	label_row.add_child(_health_label)

	# Bar background track
	var track := ColorRect.new()
	track.size = Vector2(200, 8)
	track.position = Vector2(0, -24)
	track.color = Color(0.05, 0.1, 0.15, 0.85)
	_container.add_child(track)

	# Actual health bar
	_health_bar = TextureProgressBar.new()
	_health_bar.size = Vector2(200, 8)
	_health_bar.position = Vector2(0, -24)
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0

	# Draw bar using nine-patch style flat color via theme
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.0, 0.85, 1.0, 1.0)
	bar_style.corner_radius_top_left    = 2
	bar_style.corner_radius_top_right   = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.corner_radius_bottom_right = 2

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	# Use ProgressBar instead for easier styling
	_container.remove_child(_health_bar)

	var progress := ProgressBar.new()
	progress.size = Vector2(200, 10)
	progress.position = Vector2(0, -26)
	progress.max_value = 100.0
	progress.value = 100.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", bar_style)
	progress.add_theme_stylebox_override("background", bg_style)
	_container.add_child(progress)
	_health_bar = null

	# Store reference via a different var
	_container.set_meta("progress", progress)

	# Thin glow line above the bar
	var glow_line := ColorRect.new()
	glow_line.size = Vector2(200, 1)
	glow_line.position = Vector2(0, -27)
	glow_line.color = Color(0.4, 1.0, 1.0, 0.5)
	_container.add_child(glow_line)


func _get_bar() -> ProgressBar:
	return _container.get_meta("progress") as ProgressBar


func _on_health_changed(new_health: int) -> void:
	var max_hp: int = _bike_node.max_health
	var pct := (float(new_health) / float(max_hp)) * 100.0

	var bar := _get_bar()
	bar.value = pct
	_health_label.text = "HULL  %d / %d" % [new_health, max_hp]

	# Color shifts red as health drops
	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if pct > 50.0:
		fill_style.bg_color = Color(0.0, 0.85, 1.0, 1.0)         # cyan
	elif pct > 25.0:
		fill_style.bg_color = Color(1.0, 0.75, 0.0, 1.0)         # orange
	else:
		fill_style.bg_color = Color(1.0, 0.15, 0.15, 1.0)        # red

	# Flash white on hit
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_health_label, "modulate", Color(1, 1, 1, 1), 0.0)
	_flash_tween.tween_property(_health_label, "modulate", Color(0.6, 0.95, 1.0, 0.9), 0.3)


func _on_player_died() -> void:
	_health_label.text = "HULL  0 / %d" % _bike_node.max_health
	var bar := _get_bar()
	bar.value = 0.0
	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color = Color(1.0, 0.0, 0.0, 1.0)

extends CanvasLayer

@export var bike: NodePath

var _bike_node: CharacterBody3D
var _health_label: Label
var _progress_bar: ProgressBar
var _container: VBoxContainer
var _flash_tween: Tween


func _ready() -> void:
	if bike:
		_bike_node = get_node(bike)
		_bike_node.health_changed.connect(_on_health_changed)
		_bike_node.player_died.connect(_on_player_died)

	_build_hud()
	print("HUD READY")


func _build_hud() -> void:
	# -------------------------
	# Root Container (Top Left)
	# -------------------------
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container.position = Vector2(80, 340)  # adjust to fit hole

	# 🔥 FORCE WIDTH HERE
	_container.custom_minimum_size = Vector2(70, 0)

	_container.size_flags_horizontal = Control.SIZE_FILL
	_container.add_theme_constant_override("separation", 6)

	add_child(_container)

	# -------------------------
	# Label
	# -------------------------
	_health_label = Label.new()
	_health_label.text = "HULL  50 / 50"
	_health_label.add_theme_font_size_override("font_size", 12)
	_health_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0, 0.9))
	_container.add_child(_health_label)

	# -------------------------
	# Bar Styles (Rounded)
	# -------------------------
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.85, 1.0, 1.0)
	fill_style.corner_radius_top_left = 50
	fill_style.corner_radius_top_right = 50
	fill_style.corner_radius_bottom_left = 50
	fill_style.corner_radius_bottom_right = 50

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.1, 0.15, 0.85)
	bg_style.corner_radius_top_left = 50
	bg_style.corner_radius_top_right = 50
	bg_style.corner_radius_bottom_left = 50
	bg_style.corner_radius_bottom_right = 50

	# -------------------------
	# Progress Bar
	# -------------------------
	_progress_bar = ProgressBar.new()

	# 🔥 IMPORTANT: Only control height here
	_progress_bar.custom_minimum_size = Vector2(0, 110)

	# Stretch horizontally to container width
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_progress_bar.max_value = 100.0
	_progress_bar.value = 100.0
	_progress_bar.show_percentage = false

	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	_container.add_child(_progress_bar)
# --------------------------------------------------
# HEALTH UPDATE
# --------------------------------------------------

func _on_health_changed(new_health: int) -> void:
	var max_hp: int = _bike_node.max_health
	var pct := (float(new_health) / float(max_hp)) * 100.0

	_progress_bar.value = pct
	_health_label.text = "HULL  %d / %d" % [new_health, max_hp]

	# Color shifts as health drops
	var fill_style := _progress_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if pct > 50.0:
		fill_style.bg_color = Color(0.0, 0.85, 1.0, 1.0)
	elif pct > 25.0:
		fill_style.bg_color = Color(1.0, 0.75, 0.0, 1.0)
	else:
		fill_style.bg_color = Color(1.0, 0.15, 0.15, 1.0)

	# Flash on hit
	if _flash_tween:
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.tween_property(_health_label, "modulate", Color(1, 1, 1, 1), 0.0)
	_flash_tween.tween_property(_health_label, "modulate", Color(0.6, 0.95, 1.0, 0.9), 0.3)


func _on_player_died() -> void:
	_health_label.text = "HULL  0 / %d" % _bike_node.max_health
	_progress_bar.value = 0.0

	var fill_style := _progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color = Color(1.0, 0.0, 0.0, 1.0)

extends CanvasLayer

## TransitionManager.gd
## Autoload as "TransitionManager"
## Uses hex grid shader for transitions, falls back to fade if no shader set.

@export var transition_duration: float = 1.2
@export var use_hex_transition: bool = true

var _overlay: ColorRect
var _shader_mat: ShaderMaterial
var _tween: Tween
var _busy: bool = false


func _ready() -> void:
	layer = 128

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Load the hex shader
	if use_hex_transition:
		var shader := load("res://hex_transition.gdshader")
		if shader:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader
			_overlay.material = _shader_mat


func goto(path: String) -> void:
	if _busy:
		return
	_busy = true

	if use_hex_transition and _shader_mat:
		await _hex_transition(path)
	else:
		await _fade_transition(path)

	_busy = false


func _hex_transition(path: String) -> void:
	# Capture current scene as from_tex
	await get_tree().process_frame
	var from_img := get_viewport().get_texture()

	# Show overlay with just from_tex while scene loads
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shader_mat.set_shader_parameter("from_tex", from_img)
	_shader_mat.set_shader_parameter("progress", 0.0)

	# Switch scene
	get_tree().change_scene_to_file(path)

	# Wait two frames for new scene to render
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture new scene as to_tex
	var to_img := get_viewport().get_texture()
	_shader_mat.set_shader_parameter("to_tex", to_img)

	# Animate progress 0 -> 1
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		func(v: float): _shader_mat.set_shader_parameter("progress", v),
		0.0, 1.0, transition_duration
	).set_trans(Tween.TRANS_SINE)
	await _tween.finished

	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fade_transition(path: String) -> void:
	_overlay.material = null
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color", Color(0, 0, 0, 1), 0.6)
	await _tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	_tween = create_tween()
	_tween.tween_property(_overlay, "color", Color(0, 0, 0, 0), 0.6)
	await _tween.finished

	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

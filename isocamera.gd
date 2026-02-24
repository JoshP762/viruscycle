extends Camera3D

@export var target: NodePath
@export var follow_speed: float = 10.0

@export_group("Speed Zoom")
@export var zoom_amount: float = 4.0   # How far to move back at top speed
@export var fov_increase: float = 15.0 # How much FOV grows
@export var zoom_speed: float = 2.0    # How fast the zoom reacts

var _target_node: Node3D
var _target_script: CharacterBody3D
var _base_offset: Vector3
var _current_zoom: float = 0.0

func _ready() -> void:
	_target_node = get_node(target)
	_target_script = _target_node as CharacterBody3D
	
	if is_instance_valid(_target_node):
		# Capture the exact position you set in the editor relative to the bike
		var world_offset = global_position - _target_node.global_position
		_base_offset = _target_node.global_transform.basis.inverse() * world_offset

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target_node):
		return

	# 1. Get Speed
	var speed = _target_script._speed if "_speed" in _target_script else 0.0
	var top_speed = _target_script.top_speed if "top_speed" in _target_script else 14.0
	var speed_factor = clamp(speed / top_speed, 0.0, 1.0)

	# 2. Smooth the Zoom factor
	_current_zoom = lerp(_current_zoom, speed_factor, delta * zoom_speed)
	
	# 3. Simple FOV
	fov = 75.0 + (_current_zoom * fov_increase)

	# 4. Position: Use the bike's actual rotation (basis) 
	# and only modify the local Z (forward/back)
	var offset = _base_offset
	offset.z += _current_zoom * zoom_amount 
	
	# Move the camera to: Bike Position + (Bike's Rotation * Modified Offset)
	var target_pos = _target_node.global_position + (_target_node.global_transform.basis * offset)

	# 5. Simple Look At
	look_at(_target_node.global_position, Vector3.UP)

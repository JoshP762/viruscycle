extends Node3D

@export var player_path: NodePath

@export var vertical_amplitude: float = 2.0
@export var vertical_frequency: float = 2.0


@export var side_amplitude: float = 1.5
@export var side_frequency: float = 4.0

@export var segment_scene: PackedScene
@export var segment_count: int = 12
@export var segment_spacing: int = 8   # Higher = longer worm

@export var turn_speed: float = 2.0  # Lower = slower turning

@export var slow_speed: float = 6.0
@export var fast_speed: float = 14.0

@export var slow_duration: float = 3.0
@export var fast_duration: float = 2.0

@export var acceleration_rate: float = 2.0

var _current_speed: float
var _target_speed: float
var _speed_timer: float = 0.0
var _is_fast: bool = false



var _velocity_dir: Vector3

var _player: Node3D
var _time: float = 0.0

var _segments: Array = []
var _position_history: Array[Vector3] = []

@onready var _head: Node3D = $Head
@onready var _segment_container: Node3D = $Segments


func _ready():
	_player = get_node(player_path)
	_spawn_segments()
	_velocity_dir = global_transform.basis.z.normalized()
	_current_speed = slow_speed
	_target_speed = slow_speed



	
func _process(delta):
	if !_player:
		return
	
	_time += delta
	
	_move_head(delta)
	_update_segments()
	_speed_timer += delta
	
	if _is_fast:
		if _speed_timer >= fast_duration:
			_speed_timer = 0.0
			_is_fast = false
			_target_speed = slow_speed
	else:
		if _speed_timer >= slow_duration:
			_speed_timer = 0.0
			_is_fast = true
			_target_speed = fast_speed
	
	# Smooth acceleration / deceleration
	_current_speed = lerp(_current_speed, _target_speed, delta * acceleration_rate) 
# -----------------------------
# HEAD MOVEMENT
# -----------------------------

func _move_head(delta):
	var to_player = (_player.global_position - global_position).normalized()

	# Gradually rotate toward player instead of snapping
	_velocity_dir = _velocity_dir.slerp(to_player, turn_speed * delta).normalized()

	# Forward movement
	var move = _velocity_dir * _current_speed * delta
	
	# Side-to-side snake motion
	var right = _velocity_dir.cross(Vector3.UP).normalized()
	var side_offset = right * sin(_time * side_frequency) * side_amplitude

	# Vertical motion
	var vertical_offset = Vector3.UP * sin(_time * vertical_frequency) * vertical_amplitude

	global_position += move + side_offset * delta + vertical_offset * delta

	# Rotate to face movement direction
	look_at(global_position + _velocity_dir, Vector3.UP)

	# Store position history
	_position_history.insert(0, global_position)

	var max_history = segment_count * segment_spacing
	if _position_history.size() > max_history:
		_position_history.resize(max_history)


# -----------------------------
# SEGMENTS
# -----------------------------

func _spawn_segments():
	for i in segment_count:
		var seg = segment_scene.instantiate()
		_segment_container.add_child(seg)
		_segments.append(seg)


func _update_segments():
	for i in _segments.size():
		var index = i * segment_spacing
		
		if index < _position_history.size():
			var target_pos = _position_history[index]
			_segments[i].global_position = target_pos
			
			# Optional: rotate segment toward previous history point
			if index + 1 < _position_history.size():
				var next_pos = _position_history[index + 1]
				_segments[i].look_at(next_pos, Vector3.UP)

extends CharacterBody3D

enum ForwardAxis { NEG_Z, POS_Z, NEG_X, POS_X }

@onready var _trail_spawn: Marker3D = $TrailSpawn
@onready var _floor_ray: RayCast3D = $FloorRay

@export var forward_axis: ForwardAxis = ForwardAxis.NEG_Z
@export var top_speed: float = 14.0
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0
@export var turn_speed_deg: float = 120.0
@export var gravity: float = 24.0

@export var mesh_node: NodePath
@export var max_lean_deg: float = 25.0
@export var lean_speed: float = 8.0
@export var max_pitch_deg: float = 6.0
@export var pitch_speed: float = 5.0

@export var airborne_pitch_x: float = -5.0
@export var airborne_pitch_y: float = 5.0
@export var airborne_pitch_z: float = 5.0

@export var alignment_speed: float = 8.0

var _actual_mesh_child: Node3D

#@onready var _music: AudioStreamPlayer3D = $AudioStreamPlayer3D


@export_group("Suspension")
@export var landing_bounce_intensity: float = 5
@export var landing_bounce_duration: float = 0.2

@export_group("Health")
@export var max_health: int = 50
var health: int = max_health

signal health_changed(new_health: int)
signal player_died

# --- NEW: Trail collision exports only ---
@export_group("Trail")
@export var trail_damage: int = 999
@export var trail_height: float = 1.0
@export var trail_lifetime: float = 6.0  # NEW
# --- END NEW ---

var _was_airborne: bool = false

var _current_trail: MeshInstance3D
var _current_points: Array[Vector3] = []
var _trail_segments: Array[Area3D] = []  # NEW
var _trail_timers: Array[float] = []  # NEW
var _max_trail_points: int = 400
var _trail_active: bool = false

var _speed: float = 0.0
var _mesh: Node3D
var _current_lean: float = 0.0
var _current_pitch: float = 0.0
var _prev_speed: float = 0.0

var _launched: bool = false

func _ready() -> void:
	add_to_group("player")
	if mesh_node:
		_mesh = get_node(mesh_node)
		if _mesh.get_child_count() > 0:
			_actual_mesh_child = _mesh.get_child(0)


func take_damage(amount: int) -> void:
	health -= amount
	health = clampi(health, 0, max_health)
	health_changed.emit(health)
	if health <= 0:
		player_died.emit()


func _apply_landing_bounce(impact_vel: float) -> void:
	if not is_instance_valid(_actual_mesh_child):
		return

	var impact_strength = clamp(abs(impact_vel) * landing_bounce_intensity, 0.0, 1.5)
	if impact_strength < 0.05: 
		return

	var tween = create_tween()
	tween.tween_property(_actual_mesh_child, "position:y", -impact_strength, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_actual_mesh_child, "position:y", 0.0, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	_tick_trail_lifetimes(delta)
	var vertical_vel_at_impact = velocity.y
	
	if is_on_floor() and _was_airborne:
		_apply_landing_bounce(vertical_vel_at_impact)

	_was_airborne = not is_on_floor()

	_apply_gravity(delta)
	_apply_bike_movement(delta)
	move_and_slide()
	_apply_lean_and_surface_align(delta)
	_update_trail()
	
func launch(force: float) -> void:
	velocity.y = force
	_launched = true
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		_launched = false
	else:
		if not _launched:
			velocity.y = -10

func _get_forward() -> Vector3:
	match forward_axis:
		ForwardAxis.NEG_Z: return -global_transform.basis.z
		ForwardAxis.POS_Z: return  global_transform.basis.z
		ForwardAxis.NEG_X: return -global_transform.basis.x
		ForwardAxis.POS_X: return  global_transform.basis.x
	return -global_transform.basis.z

func _apply_bike_movement(delta: float) -> void:
	var throttle := Input.get_axis("input_down", "input_up")
	var steer    := Input.get_axis("input_left", "input_right")

	_prev_speed = _speed

	var speed_factor := clampf(_speed / top_speed, 0.1, 1.0)
	rotate_y(-steer * deg_to_rad(turn_speed_deg) * speed_factor * delta)

	if throttle > 0.0:
		_speed = move_toward(_speed, top_speed * throttle, acceleration * delta)
	else:
		_speed = move_toward(_speed, 0.0, deceleration * delta)

	var forward := _get_forward()
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed

func _apply_lean_and_surface_align(delta: float) -> void:
	if not is_instance_valid(_mesh):
		return

	var steer        := Input.get_axis("input_left", "input_right")
	var speed_factor := clampf(_speed / top_speed, 0.0, 1.0)
	var target_lean   = -steer * max_lean_deg * speed_factor
	var accel         = _speed - _prev_speed
	var target_pitch  = clampf(-accel * pitch_speed, -max_pitch_deg, max_pitch_deg)

	_current_lean  = lerpf(_current_lean,  target_lean,  lean_speed  * delta)
	_current_pitch = lerpf(_current_pitch, target_pitch, pitch_speed * delta)

	var up_dir := Vector3.UP
	if _floor_ray.is_colliding():
		up_dir = _floor_ray.get_collision_normal()
	
	var body_forward := _get_forward().normalized()
	var right_dir    := body_forward.cross(up_dir).normalized()
	var final_forward := up_dir.cross(right_dir).normalized()

	var target_basis = Basis(right_dir, up_dir, -final_forward)
	target_basis = target_basis.orthonormalized()
	
	var airborne := Vector3.ZERO
	if not is_on_floor():
		airborne = Vector3(airborne_pitch_x, airborne_pitch_y, airborne_pitch_z)

	var lean_rot = Vector3(
		deg_to_rad(_current_pitch + airborne.x), 
		deg_to_rad(airborne.y),                  
		deg_to_rad(_current_lean + airborne.z)   
	)
	var lean_basis := Basis.from_euler(lean_rot)
	var full_target_basis = target_basis * lean_basis
	
	_mesh.global_transform.basis = _mesh.global_transform.basis.slerp(
		full_target_basis, 
		alignment_speed * delta
	).orthonormalized()
	
func _tick_trail_lifetimes(delta: float) -> void:
	var i := 0
	while i < _trail_timers.size():
		_trail_timers[i] -= delta
		if _trail_timers[i] <= 0.0:
			if i < _trail_segments.size() and is_instance_valid(_trail_segments[i]):
				_trail_segments[i].queue_free()
			_trail_segments.remove_at(i)
			_trail_timers.remove_at(i)
			if i < _current_points.size():
				_current_points.remove_at(i)
		else:
			i += 1
	# Rebuild mesh to reflect removed points
	if is_instance_valid(_current_trail) and _current_trail.mesh:
		var mesh := _current_trail.mesh as ImmediateMesh
		mesh.clear_surfaces()
		if _current_points.size() >= 2:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for point in _current_points:
				mesh.surface_add_vertex(point)
				mesh.surface_add_vertex(point + Vector3.UP * 1.0)
			mesh.surface_end()


func _start_new_trail():
	# NEW: clear old collision segments
	_clear_trail_segments()
	_current_points.clear()
	
	_current_trail = MeshInstance3D.new()
	_current_trail.set_as_top_level(true)
	add_child(_current_trail)
	
	var mesh := ImmediateMesh.new()
	_current_trail.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("bf7fbf")
	mat.emission_enabled = true
	mat.emission = Color("bf7fbf")
	mat.emission_energy_multiplier = 5.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_current_trail.material_override = mat
	_current_trail.global_transform = Transform3D.IDENTITY


# NEW: clears collision segments only
func _clear_trail_segments() -> void:
	for seg in _trail_segments:
		if is_instance_valid(seg):
			seg.queue_free()
	_trail_segments.clear()
	_trail_timers.clear() 


# NEW: spawns a collision box between two trail points
func _add_trail_segment(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return

	var area := Area3D.new()
	area.set_as_top_level(true)
	area.collision_mask = 0b110
	add_child(area)

	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, trail_height, 0.15)
	shape_node.shape = box
	area.add_child(shape_node)

	var mid := (from + to) * 0.5
	area.global_position = mid + Vector3.UP * (trail_height * 0.5)
	var dir := (to - from).normalized()
	if dir.length() > 0.001:
		area.global_transform = area.global_transform.looking_at(
			area.global_position + dir, Vector3.UP
		)

	area.body_entered.connect(_on_trail_hit)
	_trail_segments.append(area)
	_trail_timers.append(trail_lifetime)  # NEW


# NEW: called when something enters a trail segment
func _on_trail_hit(body: Node3D) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(trail_damage)


func _input(event):
	if event.is_action_pressed("trail_toggle"):
		_trail_active = !_trail_active
		if _trail_active:
			_start_new_trail()
		else:
			# NEW: clean up collision on toggle off
			_clear_trail_segments()

func _update_trail():
	if not _trail_active or not is_instance_valid(_current_trail):
		return
	
	var pos: Vector3 = _trail_spawn.global_transform.origin
	if _current_points.size() == 0 or _current_points[-1].distance_to(pos) > 0.3:
		# NEW: add collision segment between last and new point
		if not _current_points.is_empty():
			_add_trail_segment(_current_points[-1], pos)
		_current_points.append(pos)
	
	if _current_points.size() > _max_trail_points:
		_current_points.pop_front()
		# NEW: remove oldest collision segment
		if not _trail_segments.is_empty():
			if is_instance_valid(_trail_segments[0]):
				_trail_segments[0].queue_free()
			_trail_segments.pop_front()
	
	var mesh := _current_trail.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _current_points:
		var height := Vector3.UP * 1.0
		mesh.surface_add_vertex(point)
		mesh.surface_add_vertex(point + height)
	mesh.surface_end()

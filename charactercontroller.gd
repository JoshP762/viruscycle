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

@export var airborne_pitch_x: float = 0.0
@export var airborne_pitch_y: float = 0.0
@export var airborne_pitch_z: float = 0.0

@export var alignment_speed: float = 8.0

var _actual_mesh_child: Node3D

@export_group("Suspension")
@export var landing_bounce_intensity: float = 5 # How deep it compresses
@export var landing_bounce_duration: float = 0.2  # How fast the bounce is

var _was_airborne: bool = false

var _current_trail: MeshInstance3D
var _current_points: Array[Vector3] = []
var _max_trail_points: int = 400
var _trail_active: bool = false

var _speed: float = 0.0
var _mesh: Node3D
var _current_lean: float = 0.0
var _current_pitch: float = 0.0
var _prev_speed: float = 0.0

func _ready() -> void:
	if mesh_node:
		_mesh = get_node(mesh_node) # This is now the "MeshRotationPivot"
		if _mesh.get_child_count() > 0:
			_actual_mesh_child = _mesh.get_child(0) # This is the actual bike model


func _apply_landing_bounce(impact_vel: float) -> void:
	if not is_instance_valid(_actual_mesh_child):
		return

	# Use the velocity we captured at the moment of impact
	var impact_strength = clamp(abs(impact_vel) * landing_bounce_intensity, 0.0, 1.5)

	if impact_strength < 0.05: 
		return

	# Kill any existing tween to prevent "jitter" if we land multiple times fast
	var tween = create_tween()

	# 1. THE SQUASH: Move the mesh down relative to the pivot
	tween.tween_property(_actual_mesh_child, "position:y", -impact_strength, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. THE REBOUND: Spring back to 0
	tween.tween_property(_actual_mesh_child, "position:y", 0.0, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	var vertical_vel_at_impact = velocity.y # Capture this BEFORE move_and_slide or gravity reset
	
	if is_on_floor() and _was_airborne:
		# Pass the captured velocity to the bounce function
		_apply_landing_bounce(vertical_vel_at_impact)

	_was_airborne = not is_on_floor()

	_apply_gravity(delta)
	_apply_bike_movement(delta)
	move_and_slide()
	_apply_lean_and_surface_align(delta)
	_update_trail()
	

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Small downward force keeps is_on_floor() stable
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

	# Steering logic
	var speed_factor := clampf(_speed / top_speed, 0.1, 1.0)
	rotate_y(-steer * deg_to_rad(turn_speed_deg) * speed_factor * delta)

	# Acceleration logic
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

	# 1. CALCULATE LEAN AND PITCH (Based on player input/acceleration)
	var steer        := Input.get_axis("input_left", "input_right")
	var speed_factor := clampf(_speed / top_speed, 0.0, 1.0)
	var target_lean   = -steer * max_lean_deg * speed_factor
	var accel         = _speed - _prev_speed
	var target_pitch  = clampf(-accel * pitch_speed, -max_pitch_deg, max_pitch_deg)

	_current_lean  = lerpf(_current_lean,  target_lean,  lean_speed  * delta)
	_current_pitch = lerpf(_current_pitch, target_pitch, pitch_speed * delta)

	# 2. CALCULATE TARGET SURFACE BASIS
	var up_dir := Vector3.UP
	if _floor_ray.is_colliding():
		up_dir = _floor_ray.get_collision_normal()
	
	# Get the direction the character body is facing in the world
	var body_forward := _get_forward().normalized()
	
	# Construct the coordinate system based on the surface normal
	var right_dir    := body_forward.cross(up_dir).normalized()
	var final_forward := up_dir.cross(right_dir).normalized()

	# This is the "Base" orientation (Aligned to ground, but facing where you steer)
	var target_basis = Basis(right_dir, up_dir, -final_forward)
	target_basis = target_basis.orthonormalized()
	
	# 3. CALCULATE LOCAL ROTATION (Lean, Pitch, and Airborne tilt)
	var airborne := Vector3.ZERO
	if not is_on_floor():
		airborne = Vector3(airborne_pitch_x, airborne_pitch_y, airborne_pitch_z)

	var lean_rot = Vector3(
		deg_to_rad(_current_pitch + airborne.x), 
		deg_to_rad(airborne.y),                  
		deg_to_rad(_current_lean + airborne.z)   
	)
	var lean_basis := Basis.from_euler(lean_rot)

	# 4. COMBINE AND SMOOTH (SLERP)
	# We multiply the ground alignment by the local lean/pitch
	var full_target_basis = target_basis * lean_basis
	
	# We smoothly interpolate the mesh's current basis to the target basis
	# This prevents the bike from "snapping" instantly when hitting bumps
	_mesh.global_transform.basis = _mesh.global_transform.basis.slerp(
		full_target_basis, 
		alignment_speed * delta
	).orthonormalized()

# --- Trail Logic ---

func _start_new_trail():
	_current_points.clear()
	_current_trail = MeshInstance3D.new()
	_current_trail.set_as_top_level(true)
	add_child(_current_trail)
	
	var mesh := ImmediateMesh.new()
	_current_trail.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.8, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_current_trail.material_override = mat
	_current_trail.global_transform = Transform3D.IDENTITY

func _input(event):
	if event.is_action_pressed("trail_toggle"):
		_trail_active = !_trail_active
		if _trail_active: _start_new_trail()

func _update_trail():
	if not _trail_active or not is_instance_valid(_current_trail):
		return
	
	var pos: Vector3 = _trail_spawn.global_transform.origin
	if _current_points.size() == 0 or _current_points[-1].distance_to(pos) > 0.3:
		_current_points.append(pos)
	
	if _current_points.size() > _max_trail_points:
		_current_points.pop_front()
	
	var mesh := _current_trail.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _current_points:
		var height := Vector3.UP * 1.0
		mesh.surface_add_vertex(point)
		mesh.surface_add_vertex(point + height)
	mesh.surface_end()

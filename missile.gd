extends Area3D

@export var initial_speed: float = 3.0
@export var max_speed: float = 30.0
@export var acceleration: float = 8.0
@export var damage: int = 25
@export var splash_radius: float = 5.0
@export var lifetime: float = 8.0

@export_group("Trail")
@export var trail_color: Color = Color(1.0, 0.4, 0.0, 1.0)  # Orange/red rocket exhaust
@export var trail_height: float = 0.15
@export var trail_max_points: int = 60

var _target: Node3D = null
var _speed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _dead: bool = false

var _trail_mesh: MeshInstance3D
var _trail_points: Array[Vector3] = []


func _ready() -> void:
	_setup_trail()


func _setup_trail() -> void:
	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.set_as_top_level(true)
	add_child(_trail_mesh)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = trail_color
	mat.emission_enabled = true
	mat.emission = trail_color
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mesh.material_override = mat
	_trail_mesh.global_transform = Transform3D.IDENTITY


func setup(target: Node3D) -> void:
	_target = target
	_speed = initial_speed
	if is_instance_valid(_target):
		_velocity = (target.global_position - global_position).normalized() * _speed
	body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_cleanup_trail()
		queue_free()
		return

	_speed = move_toward(_speed, max_speed, acceleration * delta)

	if is_instance_valid(_target):
		var desired := (_target.global_position - global_position).normalized() * _speed
		_velocity = _velocity.lerp(desired, 3.0 * delta).normalized() * _speed

	global_position += _velocity * delta

	# Face direction of travel
	if _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)
		rotate_y(deg_to_rad(90))

	_update_trail()


func _update_trail() -> void:
	if not is_instance_valid(_trail_mesh):
		return

	_trail_points.append(global_position)
	if _trail_points.size() > trail_max_points:
		_trail_points.pop_front()

	if _trail_points.size() < 2:
		return

	var imesh := ImmediateMesh.new()
	_trail_mesh.mesh = imesh

	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var total := _trail_points.size()
	for i in range(total):
		var point := _trail_points[i]
		# Fade out toward the tail end
		var t := float(i) / float(total - 1)
		var w := trail_height * t  # thin at tail, full at head
		imesh.surface_add_vertex(point + Vector3.UP * w * 0.5)
		imesh.surface_add_vertex(point - Vector3.UP * w * 0.5)

	imesh.surface_end()


func _on_hit(body: Node) -> void:
	if _dead:
		return
	_dead = true
	_cleanup_trail()
	_explode()


func _cleanup_trail() -> void:
	if is_instance_valid(_trail_mesh):
		_trail_mesh.queue_free()


func _explode() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 1
	var hits := space.intersect_shape(query, 8)
	for hit in hits:
		var body = hit.collider
		if body and body.has_method("take_damage"):
			body.take_damage(damage)

	queue_free()

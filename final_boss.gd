extends CharacterBody3D

@export var player: NodePath
@export var speed_multiplier: float = 0.85
@export var detection_radius: float = 40.0
@export var gravity: float = 24.0
@export var ground_offset: float = 0.5

@export_group("Health")
@export var max_health: int = 100
var health: int = max_health

@export_group("Trail")
@export var trail_color: Color = Color(1.0, 0.1, 0.1, 1.0)
@export var trail_height: float = 1.0
@export var trail_damage: int = 999
@export var trail_lifetime: float = 5.0

@export_group("SFX")
@export var death_sound: AudioStream

var _player_node: CharacterBody3D
var _dead: bool = false
var _active: bool = false

var _trail_mesh: MeshInstance3D
var _trail_points: Array[Vector3] = []
var _trail_segments: Array[Area3D] = []
var _trail_timers: Array[float] = []
var _max_trail_points: int = 400

signal died


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	_player_node = get_node(player)
	_setup_trail()

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_active = true


func _setup_trail() -> void:
	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.set_as_top_level(true)
	add_child(_trail_mesh)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = trail_color
	mat.emission_enabled = true
	mat.emission = trail_color
	mat.emission_energy_multiplier = 5.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mesh.material_override = mat
	_trail_mesh.global_transform = Transform3D.IDENTITY


func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	health = clampi(health, 0, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	for seg in _trail_segments:
		if is_instance_valid(seg):
			seg.queue_free()
	if is_instance_valid(_trail_mesh):
		_trail_mesh.queue_free()
	get_tree().call_group("wave2", "activate")
	died.emit()
	if death_sound:
		var sfx := AudioStreamPlayer3D.new()
		get_tree().current_scene.add_child(sfx)
		sfx.global_position = global_position
		sfx.stream = death_sound
		sfx.play()
		await sfx.finished
		sfx.queue_free()
	queue_free()


func _physics_process(delta: float) -> void:
	if _dead or not _active or not is_instance_valid(_player_node):
		return

	_tick_trail_lifetimes(delta)

	# Apply gravity like the player
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -10

	# Mirror player horizontal velocity
	var pv := _player_node.velocity
	velocity.x = -pv.x * speed_multiplier
	velocity.z = -pv.z * speed_multiplier

	move_and_slide()

	# Mirror player rotation
	var player_basis := _player_node.global_transform.basis
	global_transform.basis = global_transform.basis.slerp(
		player_basis.rotated(Vector3.UP, deg_to_rad(180)),
		10.0 * delta
	).orthonormalized()

	if Vector2(pv.x, pv.z).length() > 0.5:
		_update_trail()


func _tick_trail_lifetimes(delta: float) -> void:
	var i := 0
	while i < _trail_timers.size():
		_trail_timers[i] -= delta
		if _trail_timers[i] <= 0.0:
			if i < _trail_segments.size() and is_instance_valid(_trail_segments[i]):
				_trail_segments[i].queue_free()
			_trail_segments.remove_at(i)
			_trail_timers.remove_at(i)
			if i < _trail_points.size():
				_trail_points.remove_at(i)
		else:
			i += 1
	_rebuild_trail_mesh()


func _rebuild_trail_mesh() -> void:
	if not is_instance_valid(_trail_mesh):
		return
	if _trail_points.size() < 2:
		_trail_mesh.mesh = null
		return
	var imesh := ImmediateMesh.new()
	_trail_mesh.mesh = imesh
	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _trail_points:
		imesh.surface_add_vertex(point)
		imesh.surface_add_vertex(point + Vector3.UP * trail_height)
	imesh.surface_end()


func _add_trail_segment(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var area := Area3D.new()
	area.set_as_top_level(true)
	area.collision_layer = 8
	area.collision_mask = 1
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
	_trail_timers.append(trail_lifetime)


func _on_trail_hit(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.take_damage(trail_damage)


func _update_trail() -> void:
	var pos := global_position
	if _trail_points.is_empty() or _trail_points[-1].distance_to(pos) > 0.3:
		if not _trail_points.is_empty():
			_add_trail_segment(_trail_points[-1], pos)
		_trail_points.append(pos)
	if _trail_points.size() > _max_trail_points:
		_trail_points.pop_front()
		if not _trail_segments.is_empty():
			if is_instance_valid(_trail_segments[0]):
				_trail_segments[0].queue_free()
			_trail_segments.pop_front()
			if not _trail_timers.is_empty():
				_trail_timers.pop_front()

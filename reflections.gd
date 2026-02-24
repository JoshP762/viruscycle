@tool
extends MeshInstance3D
class_name FullscreenMesh

@export_tool_button("Set up") var setup_tool = setup

func setup():
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	
	if mesh != null:
		mesh = null
		
	mesh = ArrayMesh.new()
	
	var verts = PackedVector3Array()
	verts.append(Vector3(-1.0, -1.0, 0.0))
	verts.append(Vector3(3.0, -1.0, 0.0))
	verts.append(Vector3(-1.0, 3.0, 0.0))

	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = verts

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)

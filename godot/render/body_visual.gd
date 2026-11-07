class_name BodyVisual
extends Node3D

const SURFACE_SHADER := preload("res://render/shaders/body_surface.gdshader")
const SUN_SHADER := preload("res://render/shaders/sun_surface.gdshader")
const RING_SHADER := preload("res://render/shaders/planet_ring.gdshader")
const RING_SEGMENTS := 128

var _mesh_instance := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _emissive: bool
var _ring_material: ShaderMaterial


func _init(texture_path: String, night_texture_path: String, emissive: bool, tint: Color = Color.WHITE) -> void:
	_emissive = emissive
	_material.shader = SUN_SHADER if emissive else SURFACE_SHADER
	_material.set_shader_parameter("albedo_texture", load(texture_path))
	_material.set_shader_parameter("tint", tint)
	if night_texture_path != "":
		_material.set_shader_parameter("has_night_texture", true)
		_material.set_shader_parameter("night_texture", load(night_texture_path))
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func set_mesh_detail(radial_segments: int, rings: int) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	_mesh_instance.mesh = sphere


func set_tint(tint: Color) -> void:
	_material.set_shader_parameter("tint", tint)


func place(
	camera_relative_position: Vector3,
	radius: float,
	orientation: Basis,
	sun_direction: Vector3,
	lit: bool = true
) -> void:
	transform = Transform3D(orientation.scaled(Vector3.ONE * radius), camera_relative_position)
	if not _emissive:
		_material.set_shader_parameter("sun_direction", sun_direction)
		_material.set_shader_parameter("has_sun", lit)
	if _ring_material != null:
		_ring_material.set_shader_parameter("sun_direction", sun_direction)
		_ring_material.set_shader_parameter("has_sun", lit)


func add_rings(inner_ratio: float, outer_ratio: float, texture_path: String) -> void:
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = RING_SHADER
	_ring_material.set_shader_parameter("ring_texture", load(texture_path))
	var ring := MeshInstance3D.new()
	ring.mesh = _annulus(inner_ratio, outer_ratio)
	ring.material_override = _ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


static func _annulus(inner_radius: float, outer_radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in RING_SEGMENTS + 1:
		var angle := TAU * float(index) / float(RING_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * inner_radius)
		vertices.append(direction * outer_radius)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, 0.5))
		uvs.append(Vector2(1.0, 0.5))
	for index in RING_SEGMENTS:
		var first := index * 2
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

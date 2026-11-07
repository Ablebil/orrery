class_name BodyVisual
extends Node3D

const SURFACE_SHADER := preload("res://render/shaders/body_surface.gdshader")
const SUN_SHADER := preload("res://render/shaders/sun_surface.gdshader")

var definition: BodyDefinition

var _mesh_instance := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _pole: Vector3
var _alignment: Basis


func _init(body: BodyDefinition) -> void:
	definition = body
	_pole = body.pole_direction()
	_alignment = Basis(Quaternion(Vector3.UP, _pole))
	_material.shader = SUN_SHADER if body.emissive else SURFACE_SHADER
	_material.set_shader_parameter("albedo_texture", load(body.texture_path))
	if body.night_texture_path != "":
		_material.set_shader_parameter("has_night_texture", true)
		_material.set_shader_parameter("night_texture", load(body.night_texture_path))
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


func place(camera_relative_position: Vector3, radius: float, spin: float, sun_direction: Vector3) -> void:
	var orientation := Basis(_pole, spin) * _alignment
	transform = Transform3D(orientation.scaled(Vector3.ONE * radius), camera_relative_position)
	if not definition.emissive:
		_material.set_shader_parameter("sun_direction", sun_direction)

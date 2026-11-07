class_name ReferenceRings
extends MeshInstance3D

const RING_RADII_AU: Array[float] = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0]
const SEGMENTS := 160
const RING_COLOR := Color(0.6, 0.75, 1.0, 0.2)

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func update(camera_position: PackedFloat64Array, shell: float) -> void:
	_mesh.clear_surfaces()
	if not visible:
		return
	for radius_au in RING_RADII_AU:
		var radius := _radius_units(radius_au)
		_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
		for index in SEGMENTS + 1:
			var angle := TAU * float(index) / float(SEGMENTS)
			_mesh.surface_set_color(RING_COLOR)
			_mesh.surface_add_vertex(_vertex(cos(angle) * radius, sin(angle) * radius, camera_position, shell))
		_mesh.surface_end()


func label_entries(camera_position: PackedFloat64Array, shell: float) -> Array:
	var entries: Array = []
	for radius_au in RING_RADII_AU:
		var point := _vertex(_radius_units(radius_au), 0.0, camera_position, shell)
		entries.append({"text": _label_text(radius_au), "point": point})
	return entries


func _radius_units(radius_au: float) -> float:
	return radius_au * Astro.AU_KM / SandboxRenderer.UNIT_KM


func _vertex(x: float, z: float, camera_position: PackedFloat64Array, shell: float) -> Vector3:
	var vertex := Vector3(x - camera_position[0], -camera_position[1], z - camera_position[2])
	var distance := vertex.length()
	if distance > shell:
		vertex *= shell / distance
	return vertex


func _label_text(radius_au: float) -> String:
	return "%s AU" % ("%.2f" % radius_au if radius_au < 1.0 else "%d" % int(radius_au))

class_name ReferenceRings
extends MeshInstance3D

const RING_RADII_AU: Array[float] = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0]
const SEGMENTS := 160
const RING_COLOR := Color(0.6, 0.75, 1.0, 0.2)

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _labels: Array = []


func _init() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func update(camera_position: PackedFloat64Array, shell: float, center: PackedFloat64Array, radii: Array[float]) -> void:
	_mesh.clear_surfaces()
	_labels.clear()
	if not visible:
		return
	var offset := PackedFloat64Array(
		[center[0] - camera_position[0], center[1] - camera_position[1], center[2] - camera_position[2]]
	)
	for ring in radii.size():
		var radius := radii[ring]
		_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
		for index in SEGMENTS + 1:
			var angle := TAU * float(index) / float(SEGMENTS)
			_mesh.surface_set_color(RING_COLOR)
			_mesh.surface_add_vertex(_vertex(offset, cos(angle) * radius, sin(angle) * radius, shell))
		_mesh.surface_end()
		_labels.append({"text": _label_text(RING_RADII_AU[ring]), "point": _vertex(offset, radius, 0.0, shell)})


func label_entries() -> Array:
	return _labels if visible else []


func _vertex(offset: PackedFloat64Array, x: float, z: float, shell: float) -> Vector3:
	var vertex := Vector3(offset[0] + x, offset[1], offset[2] + z)
	var distance := vertex.length()
	if distance > shell:
		vertex *= shell / distance
	return vertex


func _label_text(radius_au: float) -> String:
	return "%s AU" % ("%.2f" % radius_au if radius_au < 1.0 else "%d" % int(radius_au))

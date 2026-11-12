class_name SolarSystemModel
extends RefCounted

const SPEED_SAMPLE_SECONDS := 1800.0

var bodies: Array[BodyDefinition] = []
var relative_km: Dictionary = {}
var absolute_km: Dictionary = {}

var _by_id: Dictionary = {}


func _init(catalog: Array[BodyDefinition]) -> void:
	bodies = catalog
	for body in bodies:
		_by_id[body.id] = body


func get_body(id: String) -> BodyDefinition:
	return _by_id.get(id)


func get_parent_body(body: BodyDefinition) -> BodyDefinition:
	if body.parent_id == "":
		return null
	return _by_id.get(body.parent_id)


func relative_speed_km_s(body: BodyDefinition, simulation_seconds: float) -> float:
	if body.orbit == null:
		return 0.0
	var before := body.orbit.position_km((simulation_seconds - SPEED_SAMPLE_SECONDS) / Astro.SECONDS_PER_CENTURY)
	var after := body.orbit.position_km((simulation_seconds + SPEED_SAMPLE_SECONDS) / Astro.SECONDS_PER_CENTURY)
	return after.minus(before).length() / (2.0 * SPEED_SAMPLE_SECONDS)


func update(simulation_seconds: float) -> void:
	var centuries := simulation_seconds / Astro.SECONDS_PER_CENTURY
	for body in bodies:
		if body.orbit == null:
			relative_km[body.id] = DVec3.new()
			absolute_km[body.id] = DVec3.new()
			continue
		var relative: DVec3 = body.orbit.position_km(centuries)
		relative_km[body.id] = relative
		var parent_absolute: DVec3 = absolute_km[body.parent_id]
		absolute_km[body.id] = parent_absolute.plus(relative)


func cycle_order() -> Array[String]:
	var keyed: Array = []
	for body in bodies:
		var root := body
		while get_parent_body(root) != null and get_parent_body(root).kind != "star":
			root = get_parent_body(root)
		var own := 0.0 if body.orbit == null else body.orbit.elements[OrbitModel.SEMI_MAJOR]
		var system := 0.0 if root.orbit == null else root.orbit.elements[OrbitModel.SEMI_MAJOR]
		keyed.append([system, 0.0 if root == body else own, body.id])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var order: Array[String] = []
	for entry: Array in keyed:
		order.append(entry[2])
	return order

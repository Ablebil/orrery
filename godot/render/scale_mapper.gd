class_name ScaleMapper
extends RefCounted

enum Mode { COMPRESSED, TRUE_SCALE }

const TRUE_SCALE_UNIT_KM := 1000.0
const EARTH_RADIUS_KM := 6371.0
const RADIUS_EXPONENT := 0.5
const PLANET_ORBIT_BASE := 10.0
const PLANET_ORBIT_FACTOR := 18.0
const PLANET_ORBIT_EXPONENT := 0.55
const MOON_ORBIT_GAP := 2.0
const MOON_ORBIT_SPREAD := 1.0

var mode: Mode = Mode.COMPRESSED


func radius(body: BodyDefinition) -> float:
	if mode == Mode.TRUE_SCALE:
		return body.radius_km / TRUE_SCALE_UNIT_KM
	return pow(body.radius_km / EARTH_RADIUS_KM, RADIUS_EXPONENT)


func offset_to_render(
	body: BodyDefinition, parent: BodyDefinition, ox: float, oy: float, oz: float, out: PackedFloat64Array
) -> void:
	var factor := 1.0 / TRUE_SCALE_UNIT_KM
	if mode == Mode.COMPRESSED:
		var distance := sqrt(ox * ox + oy * oy + oz * oz)
		if distance > 0.0:
			factor = _compressed_distance(body, parent, distance) / distance
	out[0] = ox * factor
	out[1] = oz * factor
	out[2] = -oy * factor


func _compressed_distance(body: BodyDefinition, parent: BodyDefinition, distance_km: float) -> float:
	if parent.kind == "star":
		return PLANET_ORBIT_BASE + PLANET_ORBIT_FACTOR * pow(distance_km / Astro.AU_KM, PLANET_ORBIT_EXPONENT)
	var ratio := maxf(distance_km / parent.radius_km, 1.0)
	return radius(parent) + MOON_ORBIT_GAP + MOON_ORBIT_SPREAD * log(ratio) / log(10.0)

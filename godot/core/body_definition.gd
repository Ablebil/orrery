class_name BodyDefinition
extends RefCounted

var id: String
var display_name: String
var kind: String
var parent_id: String
var mass_kg: float
var radius_km: float
var orbit: OrbitModel
var pole_right_ascension_deg: float
var pole_declination_deg: float
var prime_meridian_deg: float
var rotation_rate_deg_per_day: float
var texture_path: String
var night_texture_path: String
var color: Color
var emissive: bool


static func from_dictionary(data: Dictionary) -> BodyDefinition:
	var body := BodyDefinition.new()
	body.id = data["id"]
	body.display_name = data["name"]
	body.kind = data["kind"]
	body.parent_id = data.get("parent", "")
	body.mass_kg = data["mass_kg"]
	body.radius_km = data["radius_km"]
	if data.has("orbit"):
		body.orbit = OrbitModel.from_dictionary(data["orbit"])
	var rotation: Dictionary = data["rotation"]
	body.pole_right_ascension_deg = rotation["pole_ra_deg"]
	body.pole_declination_deg = rotation["pole_dec_deg"]
	body.prime_meridian_deg = rotation["prime_meridian_deg"]
	body.rotation_rate_deg_per_day = rotation["rate_deg_per_day"]
	body.texture_path = data["texture"]
	body.night_texture_path = data.get("night_texture", "")
	body.color = Color.html(data["color"])
	body.emissive = data.get("emissive", false)
	return body


func pole_direction() -> Vector3:
	var ra := deg_to_rad(pole_right_ascension_deg)
	var dec := deg_to_rad(pole_declination_deg)
	var ecliptic := Astro.equatorial_to_ecliptic(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
	return Vector3(ecliptic[0], ecliptic[2], -ecliptic[1]).normalized()


func spin_angle(simulation_seconds: float) -> float:
	var days := simulation_seconds / Astro.SECONDS_PER_DAY
	return deg_to_rad(fposmod(prime_meridian_deg + rotation_rate_deg_per_day * days, 360.0))

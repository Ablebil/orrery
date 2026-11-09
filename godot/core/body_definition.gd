class_name BodyDefinition
extends RefCounted

const SPHERE_TO_BODY := Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))

static var _equatorial_to_render: Basis = _build_equatorial_to_render()

var id: String
var display_name: String
var kind: String
var parent_id: String
var mass_kg: float
var radius_km: float
var orbit: OrbitModel
var obliquity_deg: float
var pole_right_ascension_deg: float
var pole_declination_deg: float
var prime_meridian_deg: float
var rotation_rate_deg_per_day: float
var texture_path: String
var night_texture_path: String
var ring_inner_km := 0.0
var ring_outer_km := 0.0
var ring_texture_path := ""
var atmosphere_color := Color.WHITE
var atmosphere_thickness := 0.0
var atmosphere_intensity := 0.0
var cloud_texture_path := ""
var cloud_altitude := 0.0
var cloud_opacity := 0.0
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
	body.obliquity_deg = rotation["obliquity_deg"]
	body.pole_right_ascension_deg = rotation["pole_ra_deg"]
	body.pole_declination_deg = rotation["pole_dec_deg"]
	body.prime_meridian_deg = rotation["prime_meridian_deg"]
	body.rotation_rate_deg_per_day = rotation["rate_deg_per_day"]
	body.texture_path = data["texture"]
	body.night_texture_path = data.get("night_texture", "")
	if data.has("rings"):
		var rings: Dictionary = data["rings"]
		body.ring_inner_km = rings["inner_km"]
		body.ring_outer_km = rings["outer_km"]
		body.ring_texture_path = rings["texture"]
	if data.has("atmosphere"):
		var atmosphere: Dictionary = data["atmosphere"]
		body.atmosphere_color = Color.html(atmosphere["color"])
		body.atmosphere_thickness = atmosphere["thickness"]
		body.atmosphere_intensity = atmosphere["intensity"]
	if data.has("clouds"):
		var clouds: Dictionary = data["clouds"]
		body.cloud_texture_path = clouds["texture"]
		body.cloud_altitude = clouds["altitude"]
		body.cloud_opacity = clouds["opacity"]
	body.color = Color.html(data["color"])
	body.emissive = data.get("emissive", false)
	return body


func spin_angle(simulation_seconds: float) -> float:
	var days := simulation_seconds / Astro.SECONDS_PER_DAY
	return deg_to_rad(fposmod(prime_meridian_deg + rotation_rate_deg_per_day * days, 360.0))


func orientation(simulation_seconds: float) -> Basis:
	var node_angle := deg_to_rad(pole_right_ascension_deg + 90.0)
	var tilt_angle := deg_to_rad(90.0 - pole_declination_deg)
	var equatorial := (
		Basis(Vector3.BACK, node_angle) * Basis(Vector3.RIGHT, tilt_angle) * Basis(Vector3.BACK, spin_angle(simulation_seconds))
	)
	return _equatorial_to_render * equatorial * SPHERE_TO_BODY


static func _build_equatorial_to_render() -> Basis:
	return Basis(_render_axis(1.0, 0.0, 0.0), _render_axis(0.0, 1.0, 0.0), _render_axis(0.0, 0.0, 1.0))


static func _render_axis(x: float, y: float, z: float) -> Vector3:
	var ecliptic := Astro.equatorial_to_ecliptic(x, y, z)
	return Vector3(ecliptic[0], ecliptic[2], -ecliptic[1])

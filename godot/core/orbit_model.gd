class_name OrbitModel
extends RefCounted

const SEMI_MAJOR := 0
const ECCENTRICITY := 1
const INCLINATION := 2
const MEAN_LONGITUDE := 3
const LONGITUDE_OF_PERIAPSIS := 4
const LONGITUDE_OF_NODE := 5

var elements := PackedFloat64Array()
var rates := PackedFloat64Array()
var reference_plane := "ecliptic"

var _plane_to_ecliptic := PackedFloat64Array()


static func from_dictionary(data: Dictionary) -> OrbitModel:
	var model := OrbitModel.new()
	model.elements = PackedFloat64Array(data["elements"])
	model.rates = PackedFloat64Array(data["rates"])
	if data.has("reference_pole"):
		var pole: Array = data["reference_pole"]
		model.reference_plane = str(data.get("reference_plane", "laplace"))
		model._plane_to_ecliptic = _plane_basis(deg_to_rad(float(pole[0])), deg_to_rad(float(pole[1])))
	return model


func period_seconds() -> float:
	return Astro.SECONDS_PER_CENTURY * 360.0 / rates[MEAN_LONGITUDE]


func position_km(centuries: float) -> DVec3:
	var semi_major := elements[SEMI_MAJOR] + rates[SEMI_MAJOR] * centuries
	var eccentricity := elements[ECCENTRICITY] + rates[ECCENTRICITY] * centuries
	var inclination := elements[INCLINATION] + rates[INCLINATION] * centuries
	var mean_longitude := elements[MEAN_LONGITUDE] + rates[MEAN_LONGITUDE] * centuries
	var periapsis_longitude := elements[LONGITUDE_OF_PERIAPSIS] + rates[LONGITUDE_OF_PERIAPSIS] * centuries
	var node_longitude := elements[LONGITUDE_OF_NODE] + rates[LONGITUDE_OF_NODE] * centuries
	var mean_anomaly := deg_to_rad(wrapf(mean_longitude - periapsis_longitude, -180.0, 180.0))
	var position := Kepler.ecliptic_position(
		semi_major,
		eccentricity,
		deg_to_rad(inclination),
		deg_to_rad(periapsis_longitude - node_longitude),
		deg_to_rad(node_longitude),
		mean_anomaly
	)
	if not _plane_to_ecliptic.is_empty():
		position = _transform(position)
	return position.scaled(Astro.AU_KM)


func _transform(local: DVec3) -> DVec3:
	var m := _plane_to_ecliptic
	return DVec3.new(
		m[0] * local.x + m[1] * local.y + m[2] * local.z,
		m[3] * local.x + m[4] * local.y + m[5] * local.z,
		m[6] * local.x + m[7] * local.y + m[8] * local.z
	)


static func _plane_basis(pole_right_ascension: float, pole_declination: float) -> PackedFloat64Array:
	var node := pole_right_ascension + PI / 2.0
	var tilt := PI / 2.0 - pole_declination
	var x_axis := Astro.equatorial_to_ecliptic(cos(node), sin(node), 0.0)
	var y_axis := Astro.equatorial_to_ecliptic(-sin(node) * cos(tilt), cos(node) * cos(tilt), sin(tilt))
	var z_axis := Astro.equatorial_to_ecliptic(sin(node) * sin(tilt), -cos(node) * sin(tilt), cos(tilt))
	return PackedFloat64Array(
		[
			x_axis[0], y_axis[0], z_axis[0],
			x_axis[1], y_axis[1], z_axis[1],
			x_axis[2], y_axis[2], z_axis[2],
		]
	)

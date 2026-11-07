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


static func from_dictionary(data: Dictionary) -> OrbitModel:
	var model := OrbitModel.new()
	model.elements = PackedFloat64Array(data["elements"])
	model.rates = PackedFloat64Array(data["rates"])
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
	return position.scaled(Astro.AU_KM)

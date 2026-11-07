class_name Kepler
extends RefCounted

const MAX_ITERATIONS := 16
const TOLERANCE := 1e-12


static func eccentric_anomaly(mean_anomaly: float, eccentricity: float) -> float:
	var m := wrapf(mean_anomaly, -PI, PI)
	var e_anomaly := m + eccentricity * sin(m)
	for i in MAX_ITERATIONS:
		var delta := (e_anomaly - eccentricity * sin(e_anomaly) - m) / (1.0 - eccentricity * cos(e_anomaly))
		e_anomaly -= delta
		if absf(delta) < TOLERANCE:
			break
	return e_anomaly


static func ecliptic_position(
	semi_major: float,
	eccentricity: float,
	inclination: float,
	argument_of_periapsis: float,
	ascending_node: float,
	mean_anomaly: float
) -> DVec3:
	var e_anomaly := eccentric_anomaly(mean_anomaly, eccentricity)
	var plane_x := semi_major * (cos(e_anomaly) - eccentricity)
	var plane_y := semi_major * sqrt(1.0 - eccentricity * eccentricity) * sin(e_anomaly)
	var cos_w := cos(argument_of_periapsis)
	var sin_w := sin(argument_of_periapsis)
	var cos_n := cos(ascending_node)
	var sin_n := sin(ascending_node)
	var cos_i := cos(inclination)
	var sin_i := sin(inclination)
	return DVec3.new(
		(cos_w * cos_n - sin_w * sin_n * cos_i) * plane_x + (-sin_w * cos_n - cos_w * sin_n * cos_i) * plane_y,
		(cos_w * sin_n + sin_w * cos_n * cos_i) * plane_x + (-sin_w * sin_n + cos_w * cos_n * cos_i) * plane_y,
		(sin_w * sin_i) * plane_x + (cos_w * sin_i) * plane_y
	)

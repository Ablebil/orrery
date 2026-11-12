class_name BodyFacts
extends RefCounted

const EARTH_GRAVITY_MS2 := 9.80665
const EARTH_RADIUS_KM := 6371.0
const GRAVITATIONAL_CONSTANT_SI := 6.6743e-11
const KM_PER_MILLION := 1.0e6
const SECONDS_PER_HOUR := 3600.0
const DAYS_PER_YEAR := 365.25
const ROTATION_DAYS_THRESHOLD_HOURS := 100.0


static func rows(
	body: BodyDefinition, parent: BodyDefinition, distance_km: float, speed_km_s: float, scientist: bool
) -> Array:
	if scientist:
		return _scientist_rows(body, parent, distance_km, speed_km_s)
	return _explorer_rows(body, parent, distance_km)


static func format_number(value: float, decimals: int) -> String:
	var text := ("%." + str(decimals) + "f") % absf(value)
	var parts := text.split(".")
	var integer_part := parts[0]
	var grouped := ""
	for index in integer_part.length():
		if index > 0 and (integer_part.length() - index) % 3 == 0:
			grouped += ","
		grouped += integer_part[index]
	if parts.size() > 1:
		grouped += "." + parts[1]
	return ("-" if value < 0.0 else "") + grouped


static func format_scientific(value: float, decimals: int) -> String:
	if value == 0.0:
		return "0"
	var exponent := int(floor(log(absf(value)) / log(10.0)))
	var mantissa := value / pow(10.0, exponent)
	return ("%." + str(decimals) + "f x 10^%d") % [mantissa, exponent]


static func rotation_period_hours(body: BodyDefinition) -> float:
	return 24.0 * 360.0 / absf(body.rotation_rate_deg_per_day)


static func orbital_period_days(body: BodyDefinition) -> float:
	return body.orbit.period_seconds() / Astro.SECONDS_PER_DAY


static func surface_gravity(body: BodyDefinition) -> float:
	var radius_m := body.radius_km * 1000.0
	return GRAVITATIONAL_CONSTANT_SI * body.mass_kg / (radius_m * radius_m)


static func escape_velocity_km_s(body: BodyDefinition) -> float:
	var radius_m := body.radius_km * 1000.0
	return sqrt(2.0 * GRAVITATIONAL_CONSTANT_SI * body.mass_kg / radius_m) / 1000.0


static func _explorer_rows(body: BodyDefinition, parent: BodyDefinition, distance_km: float) -> Array:
	var rows: Array = []
	var diameter := body.radius_km * 2.0
	rows.append(["Width", "%s km (%s x Earth)" % [format_number(diameter, 0), _ratio(body.radius_km / EARTH_RADIUS_KM)]])
	if parent != null:
		rows.append([_distance_label(parent), _friendly_distance(distance_km, parent)])
		rows.append(["Year", _friendly_period(orbital_period_days(body), parent)])
	rows.append(["Day", _friendly_rotation(body)])
	rows.append(["Gravity", "%s x Earth" % _ratio(surface_gravity(body) / EARTH_GRAVITY_MS2)])
	return rows


static func _scientist_rows(body: BodyDefinition, parent: BodyDefinition, distance_km: float, speed_km_s: float) -> Array:
	var rows: Array = []
	rows.append(["Mass", "%s kg" % format_scientific(body.mass_kg, 4)])
	rows.append(["Mean radius", "%s km" % format_number(body.radius_km, 1)])
	rows.append(["Surface gravity", "%.2f m/s2" % surface_gravity(body)])
	rows.append(["Escape velocity", "%.2f km/s" % escape_velocity_km_s(body)])
	if parent != null:
		var semi_major_km: float = body.orbit.elements[OrbitModel.SEMI_MAJOR] * Astro.AU_KM
		rows.append(["Semi-major axis", _precise_distance(semi_major_km, parent)])
		rows.append(["Eccentricity", "%.4f" % body.orbit.elements[OrbitModel.ECCENTRICITY]])
		var inclination_label := _inclination_label(body, parent)
		rows.append([inclination_label, "%.2f deg" % absf(body.orbit.elements[OrbitModel.INCLINATION])])
		rows.append(["Orbital period", "%s d" % format_number(orbital_period_days(body), 3)])
		rows.append(["Current distance", _precise_distance(distance_km, parent)])
		rows.append(["Orbital speed", "%.2f km/s" % speed_km_s])
	var retrograde := " (retrograde)" if body.rotation_rate_deg_per_day < 0.0 else ""
	rows.append(["Rotation period", _precise_rotation(body) + retrograde])
	rows.append(["Axial tilt", "%.2f deg" % body.obliquity_deg])
	return rows


static func _precise_rotation(body: BodyDefinition) -> String:
	var hours := rotation_period_hours(body)
	if hours >= ROTATION_DAYS_THRESHOLD_HOURS:
		return "%s d" % format_number(hours / 24.0, 3)
	return "%s h" % format_number(hours, 3)


static func _distance_label(parent: BodyDefinition) -> String:
	return "Distance from " + parent.display_name


static func _friendly_distance(distance_km: float, parent: BodyDefinition) -> String:
	if parent.kind == "star":
		return "%s million km" % format_number(distance_km / KM_PER_MILLION, 1)
	return "%s km" % format_number(distance_km, 0)


static func _precise_distance(distance_km: float, parent: BodyDefinition) -> String:
	if parent.kind == "star":
		return "%.5f AU" % (distance_km / Astro.AU_KM)
	return "%s km" % format_number(distance_km, 0)


static func _friendly_period(days: float, parent: BodyDefinition) -> String:
	if parent.kind != "star":
		return "%s days around %s" % [format_number(days, 1), parent.display_name]
	if days < 1000.0:
		return "%s Earth days" % format_number(days, 0)
	return "%s Earth years" % format_number(days / DAYS_PER_YEAR, 1)


static func _friendly_rotation(body: BodyDefinition) -> String:
	var hours := rotation_period_hours(body)
	var text := ""
	if hours < 48.0:
		text = "%s hours" % format_number(hours, 1)
	else:
		text = "%s Earth days" % format_number(hours / 24.0, 1)
	if body.rotation_rate_deg_per_day < 0.0:
		text += ", spins backwards"
	return text


static func _ratio(value: float) -> String:
	if value >= 10.0:
		return format_number(value, 0)
	if value >= 1.0:
		return "%.1f" % value
	return "%.2f" % value


static func _inclination_label(body: BodyDefinition, parent: BodyDefinition) -> String:
	match body.orbit.reference_plane:
		"laplace":
			return "Inclination to Laplace plane"
		"equator":
			return "Inclination to %s's equator" % parent.display_name
	return "Inclination"

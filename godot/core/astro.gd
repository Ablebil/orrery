class_name Astro
extends RefCounted

const AU_KM := 149597870.7
const SECONDS_PER_DAY := 86400.0
const DAYS_PER_CENTURY := 36525.0
const SECONDS_PER_CENTURY := SECONDS_PER_DAY * DAYS_PER_CENTURY
const J2000_JULIAN_DATE := 2451545.0
const J2000_UNIX_SECONDS := 946728000.0
const GRAVITATIONAL_CONSTANT_KM := 6.6743e-20
const OBLIQUITY_J2000_DEG := 23.43928


static func unix_to_simulation_seconds(unix_seconds: float) -> float:
	return unix_seconds - J2000_UNIX_SECONDS


static func equatorial_to_ecliptic(x: float, y: float, z: float) -> Array[float]:
	var obliquity := deg_to_rad(OBLIQUITY_J2000_DEG)
	var cos_e := cos(obliquity)
	var sin_e := sin(obliquity)
	return [x, y * cos_e + z * sin_e, -y * sin_e + z * cos_e]


static func format_date(simulation_seconds: float) -> String:
	var julian_date := J2000_JULIAN_DATE + simulation_seconds / SECONDS_PER_DAY
	var z := floorf(julian_date + 0.5)
	var fraction := julian_date + 0.5 - z
	var a := z
	if z >= 2299161.0:
		var alpha := floorf((z - 1867216.25) / 36524.25)
		a = z + 1.0 + alpha - floorf(alpha / 4.0)
	var b := a + 1524.0
	var c := floorf((b - 122.1) / 365.25)
	var d := floorf(365.25 * c)
	var e := floorf((b - d) / 30.6001)
	var day_with_fraction := b - d - floorf(30.6001 * e) + fraction
	var month := int(e - 1.0) if e < 14.0 else int(e - 13.0)
	var year := int(c - 4716.0) if month > 2 else int(c - 4715.0)
	var day := int(floorf(day_with_fraction))
	var hours_fraction := (day_with_fraction - float(day)) * 24.0
	var hour := int(floorf(hours_fraction))
	var minute := int(floorf((hours_fraction - float(hour)) * 60.0))
	return "%d-%02d-%02d %02d:%02d" % [year, month, day, hour, minute]

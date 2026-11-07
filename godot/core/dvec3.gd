class_name DVec3
extends RefCounted

var x: float
var y: float
var z: float


func _init(px: float = 0.0, py: float = 0.0, pz: float = 0.0) -> void:
	x = px
	y = py
	z = pz


func plus(other: DVec3) -> DVec3:
	return DVec3.new(x + other.x, y + other.y, z + other.z)


func minus(other: DVec3) -> DVec3:
	return DVec3.new(x - other.x, y - other.y, z - other.z)


func scaled(factor: float) -> DVec3:
	return DVec3.new(x * factor, y * factor, z * factor)


func length() -> float:
	return sqrt(x * x + y * y + z * z)

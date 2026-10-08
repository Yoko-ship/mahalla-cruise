class_name SpeedCameraSettings
extends Resource
## Speed cameras on an overhead gantry. Passing under one above its limit costs points.

@export_range(0.0, 20000.0) var first_metres: float = 400.0
@export_range(50.0, 20000.0) var spawn_metres_min: float = 450.0
@export_range(50.0, 20000.0) var spawn_metres_max: float = 800.0
## Each camera picks one of these limits (speedometer km/h).
@export var limits_kmh: Array[int] = [40, 50]
## A fine is this many points, plus fine_per_kmh for every km/h over the limit.
@export_range(0, 1000) var fine_points: int = 15
@export_range(0, 100) var fine_per_kmh: int = 1
## The limit is painted on the asphalt this far before the gantry.
@export_range(0.0, 400.0) var marking_offset: float = 150.0
## The flash fades over this much travel.
@export_range(0.5, 50.0) var flash_metres: float = 8.0
@export var spawn_y: float = -40.0
@export var despawn_y: float = 860.0


func fine_for(speed_kmh: int, limit_kmh: int) -> int:
	return fine_points + fine_per_kmh * maxi(0, speed_kmh - limit_kmh)

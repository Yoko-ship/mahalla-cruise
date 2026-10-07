class_name SheepSettings
extends Resource
## Occasional flock crossing. Walking follows road travel, so every car meets the same pattern.

@export_range(0.0, 5000.0) var first_crossing_metres: float = 250.0
@export_range(50.0, 5000.0) var crossing_metres_min: float = 600.0
@export_range(50.0, 5000.0) var crossing_metres_max: float = 1000.0
## Two or three sheep keep the flock at most 78 px wide, leaving a passable side.
@export_range(1, 3) var flock_size_min: int = 2
@export_range(1, 3) var flock_size_max: int = 3
@export_range(20.0, 60.0) var spacing: float = 28.0
@export_range(0.0, 20.0) var row_jitter: float = 8.0
## Sideways walking per pixel of road travel.
@export_range(0.05, 1.0) var walk_per_travel: float = 0.25
@export var collision_half_size := Vector2(11, 8)

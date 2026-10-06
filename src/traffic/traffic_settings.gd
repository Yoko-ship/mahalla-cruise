class_name TrafficSettings
extends Resource
## Gentle traffic and contact tuning; shared resources remain read-only in play.

@export_range(1.0, 2000.0) var first_spawn_distance: float = 150.0
@export_range(1.0, 2000.0) var spawn_distance_min: float = 550.0
@export_range(1.0, 2000.0) var spawn_distance_max: float = 720.0
@export_range(0.1, 1.0) var relative_speed: float = 0.62
@export_range(1, 8) var max_vehicles: int = 3
@export var spawn_y: float = -60.0
@export var despawn_y: float = 840.0
@export_range(100.0, 500.0) var minimum_gap: float = 180.0
@export var collision_half_size := Vector2(20, 36)
@export_range(0.0, 5000.0) var difficulty_start_metres: float = 150.0
@export_range(1.0, 10000.0) var difficulty_full_metres: float = 900.0
@export_range(0.5, 1.0) var minimum_spawn_scale: float = 0.72

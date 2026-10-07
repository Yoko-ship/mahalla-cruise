class_name PowerUpSettings
extends Resource
## Road power-ups. Durations are metres of travel, so pausing freezes them.

const KINDS: Array[String] = ["magnet", "double", "shield"]

@export_range(0.0, 5000.0) var first_spawn_metres: float = 120.0
@export_range(20.0, 5000.0) var spawn_metres_min: float = 300.0
@export_range(20.0, 5000.0) var spawn_metres_max: float = 500.0
@export_range(1.0, 2000.0) var magnet_metres: float = 90.0
@export_range(1.0, 2000.0) var double_metres: float = 110.0
## Protection after the shield breaks, so the next car or sheep cannot end the run at once.
@export_range(0.0, 200.0) var shield_grace_metres: float = 15.0
@export_range(10.0, 400.0) var magnet_radius: float = 130.0
## Magnet pull in pixels per pixel of road travel.
@export_range(0.1, 5.0) var magnet_pull: float = 1.4
@export var collision_half_size := Vector2(16, 16)

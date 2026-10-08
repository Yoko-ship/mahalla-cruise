class_name CarSettings
extends Resource
## Per-car tuning. Treat loaded resources as read-only during play.

## Multiplies the road scroll speed while this car drives.
@export_range(0.5, 2.0) var travel_speed_scale: float = 1.0
@export_range(1.0, 2000.0) var steering_speed: float = 640.0
@export_range(0.1, 3.0) var drag_sensitivity: float = 1.0
@export_range(0.0, 100.0) var road_margin: float = 26.0
@export_range(0.0, 0.5) var max_lean: float = 0.12
@export_range(0.0, 0.1) var lean_per_pixel: float = 0.012
@export_range(1.0, 30.0) var lean_response: float = 12.0
@export var collision_half_size := Vector2(20, 36)
## Holding the brake slows travel to this share of full speed.
@export_range(0.2, 1.0) var brake_speed_share: float = 0.5
## Share of full speed lost per second while braking, and regained per second after.
@export_range(0.1, 5.0) var brake_rate: float = 0.8
@export_range(0.1, 5.0) var recover_rate: float = 0.5

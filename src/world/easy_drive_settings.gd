class_name EasyDriveSettings
extends Resource
## Easy-mode tuning. Build a private traffic configuration; never edit catalogue resources.

@export_range(1, 50) var collection_target: int = 5
@export_range(0, 1000) var collection_bonus: int = 15
@export_range(0.0, 30.0) var collection_side_margin: float = 8.0
@export_range(80.0, 220.0) var speed_limit_pixels: float = 180.0
@export_range(0.2, 0.9) var bump_speed_share: float = 0.55
@export_range(0.5, 5.0) var bump_seconds: float = 2.0
@export_range(200.0, 2000.0) var first_car_pixels: float = 900.0
@export var car_gap := Vector2(900.0, 1150.0)
@export_range(0.1, 1.0) var traffic_speed: float = 0.4
@export_range(1, 3) var max_cars: int = 2
@export_range(100.0, 500.0) var minimum_gap: float = 280.0


func pickups_for(source: PickupSettings) -> PickupSettings:
	var result := source.duplicate() as PickupSettings
	result.collection_side_margin = collection_side_margin
	return result


func traffic_for(source: TrafficSettings) -> TrafficSettings:
	var result := source.duplicate() as TrafficSettings
	result.first_spawn_distance = first_car_pixels
	result.spawn_distance_min = car_gap.x
	result.spawn_distance_max = car_gap.y
	result.relative_speed = traffic_speed
	result.max_vehicles = max_cars
	result.minimum_gap = minimum_gap
	result.minimum_spawn_scale = 1.0
	result.lane_inset_pixels = 0.0
	result.sheep_enabled = false
	result.near_miss_points = 0
	return result

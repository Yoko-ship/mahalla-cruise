class_name RoadSettings
extends Resource
## Shared route geometry and travel tuning. Runtime progress lives in CruiseGame.

@export_range(0.0, 1000.0) var scroll_speed: float = 220.0
@export var left_edge: float = 124.0
@export var right_edge: float = 308.0
@export_range(1.0, 100.0) var pixels_per_metre: float = 20.0
## Arcade speedometer: shown km/h per real km/h of travel, so a Damas cruises at 60.
@export_range(0.1, 10.0) var speedometer_scale: float = 1.52


func kmh(pixels_per_second: float) -> int:
	return roundi(pixels_per_second / pixels_per_metre * 3.6 * speedometer_scale)

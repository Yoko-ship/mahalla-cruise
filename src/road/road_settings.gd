class_name RoadSettings
extends Resource
## Shared route geometry and travel tuning. Runtime progress lives in CruiseGame.

@export_range(0.0, 1000.0) var scroll_speed: float = 220.0
@export var left_edge: float = 124.0
@export var right_edge: float = 308.0
@export_range(1.0, 100.0) var pixels_per_metre: float = 20.0

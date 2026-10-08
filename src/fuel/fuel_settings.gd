class_name FuelSettings
extends Resource
## Methane tank and METAN stations. Fuel is measured in metres of driving.

## A full tank lasts this far; the tank upgrade multiplies it.
@export_range(100.0, 20000.0) var tank_metres: float = 1500.0
@export_range(0.0, 20000.0) var first_station_metres: float = 550.0
@export_range(50.0, 20000.0) var station_metres_min: float = 500.0
@export_range(50.0, 20000.0) var station_metres_max: float = 700.0
## The car's left edge must come this close to the curb while level with the station.
@export_range(0.0, 60.0) var refuel_distance: float = 18.0
## Height of the refuel zone beside the station.
@export_range(20.0, 300.0) var zone_height: float = 80.0
## Below this share of the tank the gauge turns red and a warning shows once.
@export_range(0.0, 1.0) var low_share: float = 0.25
@export var spawn_y: float = -100.0
@export var despawn_y: float = 900.0

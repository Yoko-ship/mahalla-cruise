class_name FuelController
extends Node2D
## The methane tank and METAN stations on the left sidewalk. Driving drains the tank by
## distance; hugging the left curb beside a station fills it. A station with a queue needs
## time in the bay (braking helps); leaving early fills part of the tank. An empty tank
## ends the run. Signals upward only; never reads siblings or the HUD.

signal refueled
## Left a queued station early: the tank is now at this percent.
signal partly_refueled(percent: int)
## A station with this many waiting cars has appeared.
signal queue_ahead(cars: int)
signal running_low
signal ran_out
## Share of the tank left, and whether it is below the low mark.
signal level_changed(share: float, low: bool)

const STATION_SCENE: PackedScene = preload("res://src/fuel/fuel_station.tscn")

@export var settings: FuelSettings

var stations: Array[FuelStation] = []
## Set by the world while a police post holds the left curb; due stations wait.
var hold_stations: bool = false
var capacity_metres: float = 0.0
var fuel_metres: float = 0.0
var _capacity_scale: float = 1.0
var _road: RoadSettings
var _vertical_padding: float = 0.0
var _metres_until_station: float = 0.0
var _random := RandomNumberGenerator.new()
var _empty: bool = false
var _warned: bool = false


func configure(road: RoadSettings) -> void:
	assert(settings != null, "Fuel requires FuelSettings")
	for station in stations:
		remove_child(station)
		station.queue_free()
	stations.clear()
	_road = road
	_metres_until_station = settings.first_station_metres
	_fill()


## Tank upgrades apply between drives; the tank starts full.
func set_capacity_scale(scale: float) -> void:
	_capacity_scale = maxf(0.1, scale)
	_fill()


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


func share() -> float:
	return fuel_metres / capacity_metres if capacity_metres > 0.0 else 0.0


## seconds: real time this frame took, for waiting in a queue.
func advance(travel_pixels: float, player_bounds: Rect2, seconds: float = 0.0) -> void:
	if _empty:
		return
	var metres := travel_pixels / _road.pixels_per_metre
	for index in range(stations.size() - 1, -1, -1):
		var station := stations[index]
		var previous := station.refuel_zone(settings.refuel_distance)
		station.advance(travel_pixels)
		var zone := previous.merge(station.refuel_zone(settings.refuel_distance))
		if station.is_open and zone.intersects(player_bounds):
			station.waited += seconds
			if station.waited >= station.queue * settings.wait_seconds_per_car:
				station.serve()
				_fill()
				refueled.emit()
		elif station.is_open and station.waited > 0.0 and previous.position.y > player_bounds.end.y:
			_part_fill(station)
		if station.position.y > settings.despawn_y + _vertical_padding:
			stations.remove_at(index)
			remove_child(station)
			station.queue_free()
	fuel_metres = maxf(0.0, fuel_metres - metres)
	_metres_until_station -= metres
	if _metres_until_station <= 0.0 and stations.is_empty() and not hold_stations:
		_spawn_station()
	var low := share() < settings.low_share
	level_changed.emit(share(), low)
	if low and not _warned and fuel_metres > 0.0:
		_warned = true
		running_low.emit()
	if fuel_metres <= 0.0:
		_empty = true
		ran_out.emit()


func _fill() -> void:
	capacity_metres = settings.tank_metres * _capacity_scale
	fuel_metres = capacity_metres
	_empty = false
	_warned = false
	level_changed.emit(1.0, false)


func _spawn_station() -> void:
	var station := STATION_SCENE.instantiate() as FuelStation
	station.position = Vector2(_road.left_edge, settings.spawn_y - _vertical_padding)
	add_child(station)
	var queue := 0
	if _random.randf() < settings.queue_chance:
		queue = _random.randi_range(1, settings.queue_max)
	station.configure(settings.zone_height, settings.refuel_distance, queue)
	stations.append(station)
	_metres_until_station = _random.randf_range(
		settings.station_metres_min, settings.station_metres_max
	)
	if queue > 0:
		queue_ahead.emit(queue)


## Waited part of the queue, then drove on: that share of the missing fuel is added.
func _part_fill(station: FuelStation) -> void:
	var waited_share := station.waited / (station.queue * settings.wait_seconds_per_car)
	station.serve()
	fuel_metres += (capacity_metres - fuel_metres) * clampf(waited_share, 0.0, 1.0)
	# Back above the low mark, the warning may show again later.
	_warned = _warned and share() < settings.low_share
	partly_refueled.emit(roundi(share() * 100.0))

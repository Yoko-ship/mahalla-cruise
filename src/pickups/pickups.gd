class_name PickupController
extends Node2D
## Spawns reachable money and power-ups and signals collections; never reads siblings or the HUD.
## Power-up effects (magnet, double points, shield) are pickup state owned here.
## Marshrutka passengers at bus stops pay their fare as soʻm notes through `collected`.

signal collected(points: int, note: BanknoteDefinition)
signal power_up_collected(kind: String)
## Emitted while effects run, with PowerUpEffects.view().
signal power_ups_changed(view: Dictionary)

const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const LANES: Array[float] = [0.25, 0.5, 0.75]
const POWER_UP_SCENE: PackedScene = preload("res://src/pickups/power_up.tscn")
## A power-up never spawns this close (vertically) to a note, so they never overlap.
const POWER_UP_MONEY_GAP: float = 60.0
const BUS_STOP_SCENE: PackedScene = preload("res://src/pickups/bus_stop.tscn")

@export var power_up_settings: PowerUpSettings
@export var passenger_settings: PassengerSettings

var items: Array[MoneyPickup] = []
var power_ups: Array[PowerUp] = []
var effects: PowerUpEffects
var bus_stops: Array[BusStop] = []
## Set by the world while the curb is taken by a taxi order; due stops wait.
var hold_stops: bool = false
var _road: RoadSettings
var _settings: PickupSettings
var _distance_until_spawn: float = 0.0
var _next_lane: int = 1
var _random := RandomNumberGenerator.new()
var _vertical_padding: float = 0.0
var _metres_until_power_up: float = 0.0
var _metres_until_stop: float = 0.0
var _fare: BanknoteDefinition


func configure(road: RoadSettings, settings: PickupSettings) -> void:
	for item in items:
		remove_child(item)
		item.queue_free()
	items.clear()
	for power_up in power_ups:
		remove_child(power_up)
		power_up.queue_free()
	power_ups.clear()
	for stop in bus_stops:
		remove_child(stop)
		stop.queue_free()
	bus_stops.clear()
	_metres_until_stop = passenger_settings.first_stop_metres
	effects = PowerUpEffects.new(power_up_settings)
	_metres_until_power_up = power_up_settings.first_spawn_metres
	power_ups_changed.emit(effects.view())
	_road = road
	_settings = settings
	_fare = null
	for note in settings.som_notes:
		if note.face_value == passenger_settings.fare_face_value:
			_fare = note

	_distance_until_spawn = settings.first_spawn_distance
	_next_lane = 1


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


func advance(
	travel_pixels: float,
	player_bounds: Rect2,
	traffic_bounds: Array[Rect2],
	traffic_speed_ratio: float
) -> void:
	var was_active := effects.is_active()
	effects.advance(travel_pixels / _road.pixels_per_metre)
	_advance_power_ups(travel_pixels, player_bounds)
	_advance_bus_stops(travel_pixels, player_bounds)
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		var previous := item.collection_bounds()
		item.advance(travel_pixels)
		if effects.magnet_active():
			_pull(item, player_bounds.get_center(), travel_pixels)
		if previous.merge(item.collection_bounds()).intersects(player_bounds):
			_remove_item(index)
			collected.emit(item.points * effects.multiplier(), item.denomination)
		elif item.position.y > _settings.despawn_y + _vertical_padding:
			_remove_item(index)
	_distance_until_spawn = maxf(0.0, _distance_until_spawn - travel_pixels)
	var obstacles := traffic_bounds.duplicate()
	for power_up in power_ups:
		obstacles.append(power_up.collection_bounds())
	if _distance_until_spawn <= 0.0 and items.size() < _settings.max_pickups:
		_try_spawn(player_bounds, obstacles, traffic_speed_ratio)
	_metres_until_power_up -= travel_pixels / _road.pixels_per_metre
	if _metres_until_power_up <= 0.0 and power_ups.is_empty():
		_try_spawn_power_up(player_bounds, traffic_bounds, traffic_speed_ratio)
	_metres_until_stop -= travel_pixels / _road.pixels_per_metre
	# Without a matching fare note in the catalogue, stops are simply not offered.
	if _metres_until_stop <= 0.0 and bus_stops.is_empty() and _fare != null and not hold_stops:
		_spawn_bus_stop()
	if was_active or effects.is_active():
		power_ups_changed.emit(effects.view())


func point_multiplier() -> int:
	return effects.multiplier()


## Lets a shield (or its short grace) absorb a crash. Main asks before ending the run.
func absorb_crash() -> bool:
	var absorbed := effects.absorb_crash()
	power_ups_changed.emit(effects.view())
	return absorbed


func _advance_power_ups(travel_pixels: float, player_bounds: Rect2) -> void:
	for index in range(power_ups.size() - 1, -1, -1):
		var power_up := power_ups[index]
		var previous := power_up.collection_bounds()
		power_up.advance(travel_pixels)
		var taken := previous.merge(power_up.collection_bounds()).intersects(player_bounds)
		if taken or power_up.position.y > _settings.despawn_y + _vertical_padding:
			power_ups.remove_at(index)
			remove_child(power_up)
			power_up.queue_free()
		if taken:
			effects.activate(power_up.kind)
			power_up_collected.emit(power_up.kind)


func _advance_bus_stops(travel_pixels: float, player_bounds: Rect2) -> void:
	for index in range(bus_stops.size() - 1, -1, -1):
		var stop := bus_stops[index]
		var previous := stop.boarding_zone(passenger_settings.board_distance)
		stop.advance(travel_pixels)
		var zone := previous.merge(stop.boarding_zone(passenger_settings.board_distance))
		if stop.passengers > 0 and zone.intersects(player_bounds):
			# Every passenger pays one fare note; double points applies to each.
			for _passenger in range(stop.board()):
				collected.emit(_settings.points_for(_fare) * effects.multiplier(), _fare)
		if stop.position.y > _settings.despawn_y + _vertical_padding + 60.0:
			bus_stops.remove_at(index)
			remove_child(stop)
			stop.queue_free()


func _spawn_bus_stop() -> void:
	var stop := BUS_STOP_SCENE.instantiate() as BusStop
	stop.position = Vector2(_road.right_edge, _settings.spawn_y - _vertical_padding - 60.0)
	add_child(stop)
	var count := _random.randi_range(
		passenger_settings.passengers_min, passenger_settings.passengers_max
	)
	stop.configure(count, _road.right_edge, passenger_settings.zone_height)
	bus_stops.append(stop)
	_metres_until_stop = _random.randf_range(
		passenger_settings.stop_metres_min, passenger_settings.stop_metres_max
	)


func _pull(item: MoneyPickup, target: Vector2, travel_pixels: float) -> void:
	var offset := target - item.position
	if offset.length() <= power_up_settings.magnet_radius:
		item.position += offset.limit_length(power_up_settings.magnet_pull * travel_pixels)


func _try_spawn_power_up(
	player_bounds: Rect2, traffic_bounds: Array[Rect2], traffic_speed_ratio: float
) -> void:
	var spawn_y := _settings.spawn_y - _vertical_padding
	for item in items:
		if absf(item.position.y - spawn_y) < POWER_UP_MONEY_GAP:
			return
	var lane := _random.randi_range(0, LANES.size() - 1)
	var x := lerpf(_road.left_edge, _road.right_edge, LANES[lane])
	if not _is_clear(x, player_bounds, traffic_bounds, traffic_speed_ratio):
		return
	var power_up := POWER_UP_SCENE.instantiate() as PowerUp
	power_up.position = Vector2(x, spawn_y)
	add_child(power_up)
	var kinds := PowerUpSettings.KINDS
	power_up.configure(
		kinds[_random.randi_range(0, kinds.size() - 1)], power_up_settings.collision_half_size
	)
	power_ups.append(power_up)
	_metres_until_power_up = _random.randf_range(
		power_up_settings.spawn_metres_min, power_up_settings.spawn_metres_max
	)


func item_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for item in items:
		bounds.append(item.collection_bounds())
	return bounds


func _remove_item(index: int) -> void:
	var item := items[index]
	items.remove_at(index)
	remove_child(item)
	item.queue_free()


func _try_spawn(
	player_bounds: Rect2, traffic_bounds: Array[Rect2], traffic_speed_ratio: float
) -> void:
	for offset in range(LANES.size()):
		var lane := (_next_lane + offset) % LANES.size()
		var x := lerpf(_road.left_edge, _road.right_edge, LANES[lane])
		if not _is_clear(x, player_bounds, traffic_bounds, traffic_speed_ratio):
			continue
		var item := MONEY_SCENE.instantiate() as MoneyPickup
		item.position = Vector2(x, _settings.spawn_y - _vertical_padding)
		add_child(item)
		var dollar := _random.randf() < _settings.dollar_chance
		var note := _settings.select_note(dollar, _random.randf())
		item.configure(note, _settings.points_for(note), _settings.collision_half_size)
		items.append(item)
		_distance_until_spawn = _settings.spawn_distance
		_next_lane = (lane + 1) % LANES.size()
		return


func _is_clear(
	x: float, player_bounds: Rect2, traffic_bounds: Array[Rect2], traffic_speed_ratio: float
) -> bool:
	# Check the full relative path up to collection, including the gap for steering.
	var half := _settings.collision_half_size
	var room := Vector2(maxf(player_bounds.size.x * 0.5, half.x) + 4.0, half.y)
	var spawn_y := _settings.spawn_y - _vertical_padding
	return RoadPath.is_clear(
		x,
		spawn_y,
		room,
		player_bounds.get_center().y,
		traffic_bounds,
		traffic_speed_ratio,
		_settings.traffic_clearance
	)

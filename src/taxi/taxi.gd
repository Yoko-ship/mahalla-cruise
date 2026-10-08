class_name TaxiController
extends Node2D
## Taxi orders on the right curb: one passenger hails at a time; after boarding, the ride
## counts down and the drop-off bay arrives exactly when it ends. Pulling in there pays the
## fare in soʻm notes; driving past loses it. Signals upward; never reads siblings or the HUD.

signal called
signal boarded(ride_metres: int)
## The fare: count notes of this value, points each before bonuses.
signal delivered(note: BanknoteDefinition, count: int, points: int)
signal missed

const SPOT_SCENE: PackedScene = preload("res://src/taxi/taxi_spot.tscn")

@export var settings: TaxiSettings

var spots: Array[TaxiSpot] = []
var is_riding: bool = false
## Extra fare notes per ride: passengers tip cars with rarer number plates.
var tip_notes: int = 0
## Metres of the current ride still to go; the drop-off is due at zero.
var ride_left: float = 0.0
var _ride_notes: int = 0
var _drop_off: TaxiSpot
var _road: RoadSettings
var _fare: BanknoteDefinition
var _fare_points: int = 0
var _vertical_padding: float = 0.0
var _metres_until_order: float = 0.0
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings, money: PickupSettings) -> void:
	assert(settings != null, "Taxi requires TaxiSettings")
	for spot in spots:
		remove_child(spot)
		spot.queue_free()
	spots.clear()
	_drop_off = null
	is_riding = false
	ride_left = 0.0
	_road = road
	_metres_until_order = settings.first_order_metres
	_fare = null
	for note in money.som_notes:
		if note.face_value == settings.fare_face_value:
			_fare = note
			_fare_points = money.points_for(note)


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


## A hail on screen or a passenger aboard; bus stops wait meanwhile.
func is_busy() -> bool:
	return is_riding or _waiting_hail() != null


## Metres to the drop-off, or -1 without a passenger.
func ride_metres() -> int:
	return ceili(maxf(0.0, ride_left)) if is_riding else -1


## curb_clear: no bus stop is on the right curb, so a passenger may hail.
func advance(travel_pixels: float, player_bounds: Rect2, curb_clear: bool) -> void:
	var metres := travel_pixels / _road.pixels_per_metre
	for index in range(spots.size() - 1, -1, -1):
		var spot := spots[index]
		var previous := spot.zone(settings.board_distance)
		spot.advance(travel_pixels)
		var reached := previous.merge(spot.zone(settings.board_distance)).intersects(player_bounds)
		if not spot.is_served and reached:
			_serve(spot)
		elif spot == _drop_off and not spot.is_served and previous.position.y > player_bounds.end.y:
			_drop_off = null
			is_riding = false
			_schedule_order()
			missed.emit()
		if spot.position.y > settings.despawn_y + _vertical_padding:
			if not spot.is_served and not spot.is_drop_off:
				_schedule_order()
			spots.remove_at(index)
			remove_child(spot)
			spot.queue_free()
	if is_riding:
		ride_left -= metres
		if _drop_off == null:
			_try_place_drop_off(player_bounds.get_center().y)
	elif not is_busy():
		_metres_until_order -= metres
		if _metres_until_order <= 0.0 and curb_clear and _fare != null:
			_add_spot(false, settings.spawn_y - _vertical_padding)
			called.emit()


func _serve(spot: TaxiSpot) -> void:
	spot.serve()
	if spot.is_drop_off:
		_drop_off = null
		is_riding = false
		_schedule_order()
		delivered.emit(_fare, _ride_notes + tip_notes, _fare_points)
		return
	is_riding = true
	ride_left = roundf(_random.randf_range(settings.ride_metres_min, settings.ride_metres_max))
	_ride_notes = settings.notes_for(ride_left)
	boarded.emit(int(ride_left))


## The bay is placed so its centre reaches the car exactly when the ride ends.
func _try_place_drop_off(player_y: float) -> void:
	var y := player_y - ride_left * _road.pixels_per_metre
	if y >= settings.spawn_y - _vertical_padding:
		_drop_off = _add_spot(true, y)


func _add_spot(drop_off: bool, y: float) -> TaxiSpot:
	var spot := SPOT_SCENE.instantiate() as TaxiSpot
	spot.position = Vector2(_road.right_edge, y)
	add_child(spot)
	spot.configure(drop_off, _road.right_edge, settings.zone_height, settings.board_distance)
	spots.append(spot)
	return spot


func _waiting_hail() -> TaxiSpot:
	for spot in spots:
		if not spot.is_drop_off and not spot.is_served:
			return spot
	return null


func _schedule_order() -> void:
	_metres_until_order = _random.randf_range(settings.order_metres_min, settings.order_metres_max)

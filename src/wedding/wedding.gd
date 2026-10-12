class_name WeddingController
extends Node2D
## Toʻy korteji: now and then a decorated wedding convoy arrives ahead in one lane, cruises in
## front of the player while guests throw sochqi (money) behind it, then drives off. The world
## holds traffic while one is due and drops the thrown notes through pickups. Signals upward;
## never reads siblings or the HUD.

signal arrived
## One thrown note: where it lands and its soʻm face value.
signal tossed(spot: Vector2, face_value: int)

enum Phase { NONE, ARRIVING, CRUISING, LEAVING }

const CAR_SCENE: PackedScene = preload("res://src/wedding/wedding_car.tscn")
## Extra room beside the convoy lane that other road objects keep clear of.
const LANE_MARGIN: float = 6.0
## Half the room a thrown note needs; one that would land on something else is not thrown.
const NOTE_ROOM := Vector2(22, 16)

@export var settings: WeddingSettings

## Lead car first; the last car is the one nearest the player.
var cars: Array[WeddingCar] = []
var phase: Phase = Phase.NONE
var lane_x: float = 0.0
var _road: RoadSettings
var _vertical_padding: float = 0.0
var _metres_until_convoy: float = 0.0
var _cruise_pixels: float = 0.0
var _pixels_until_toss: float = 0.0
var _random := RandomNumberGenerator.new()
var _avoid: Array[Rect2] = []


func configure(road: RoadSettings) -> void:
	assert(settings != null, "Weddings require WeddingSettings")
	assert(settings.convoy_metres_max >= settings.convoy_metres_min)
	_clear()
	_road = road
	_metres_until_convoy = settings.first_metres


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


## A convoy is due or on the road: traffic should add no cars or sheep meanwhile.
func wants_road() -> bool:
	return phase != Phase.NONE or _metres_until_convoy <= 0.0


## road_clear: no traffic car or sheep is left on the road, so a due convoy may arrive.
## avoid: hazards and power-ups, which thrown notes must not land on.
func advance(travel_pixels: float, road_clear: bool, avoid: Array[Rect2] = []) -> void:
	_avoid = avoid
	for car in cars:
		car.animate(travel_pixels)
	match phase:
		Phase.NONE:
			_metres_until_convoy -= travel_pixels / _road.pixels_per_metre
			if _metres_until_convoy <= 0.0 and road_clear:
				_start()
		Phase.ARRIVING:
			_move(travel_pixels * settings.arrive_rate)
			if cars.back().position.y >= settings.cruise_y:
				_move(settings.cruise_y - cars.back().position.y)
				_set_phase(Phase.CRUISING)
		Phase.CRUISING:
			_cruise(travel_pixels)
		Phase.LEAVING:
			_move(-travel_pixels * settings.leave_rate)
			if cars.back().collision_bounds().end.y < settings.spawn_y - _vertical_padding:
				_clear()
				_metres_until_convoy = _random.randf_range(
					settings.convoy_metres_min, settings.convoy_metres_max
				)


## While a convoy is on the road, its whole lane: other road objects spawn elsewhere.
func blocking_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	if not cars.is_empty():
		var half := settings.collision_half_size.x + LANE_MARGIN
		var top := settings.spawn_y - _vertical_padding - settings.car_gap * settings.cars
		bounds.append(Rect2(lane_x - half, top, half * 2.0, 2000.0 + _vertical_padding * 2.0))
	return bounds


func _start() -> void:
	lane_x = lerpf(_road.left_edge, _road.right_edge, 0.25 if _random.randf() < 0.5 else 0.75)
	var top := settings.spawn_y - _vertical_padding
	for index in range(settings.cars):
		var car := CAR_SCENE.instantiate() as WeddingCar
		car.position = Vector2(lane_x, top - (settings.cars - 1 - index) * settings.car_gap)
		add_child(car)
		car.configure(settings.collision_half_size, index == 0)
		cars.append(car)
	_cruise_pixels = 0.0
	_pixels_until_toss = settings.toss_pixels * 0.5
	_set_phase(Phase.ARRIVING)
	arrived.emit()


func _cruise(travel_pixels: float) -> void:
	_cruise_pixels += travel_pixels
	_pixels_until_toss -= travel_pixels
	if _pixels_until_toss <= 0.0:
		_pixels_until_toss += settings.toss_pixels
		_toss()
	if _cruise_pixels >= settings.cruise_metres * _road.pixels_per_metre:
		_set_phase(Phase.LEAVING)


## A handful of notes lands behind the last car, spread across its lane and staggered so
## neighbouring notes do not cover each other.
func _toss() -> void:
	var tail: Rect2 = cars.back().collision_bounds()
	var count := settings.notes_per_toss
	for index in range(count):
		var side := 0.0 if count == 1 else lerpf(-1.0, 1.0, float(index) / (count - 1))
		var spot := Vector2(
			lane_x + side * settings.toss_spread,
			(
				tail.end.y
				+ settings.toss_gap
				+ (index % 2) * settings.toss_depth
				+ _random.randf() * settings.toss_depth * 0.4
			)
		)
		var value := settings.pick_value(_random.randf())
		var room := Rect2(spot - NOTE_ROOM, NOTE_ROOM * 2.0)
		if _avoid.all(func(other: Rect2) -> bool: return not other.intersects(room)):
			tossed.emit(spot, value)


func _move(pixels: float) -> void:
	for car in cars:
		car.move(pixels)


func _set_phase(next: Phase) -> void:
	phase = next
	for car in cars:
		car.playing = next == Phase.CRUISING


func _clear() -> void:
	for car in cars:
		remove_child(car)
		car.queue_free()
	cars.clear()
	_set_phase(Phase.NONE)

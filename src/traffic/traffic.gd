class_name TrafficController
extends Node2D
## Spawns spaced vehicles and sheep crossings and reports contact, without the player or HUD.

signal contacted
## Points already include the combo multiplier.
signal near_missed(points: int, combo: int)

const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const PAINTS: Array[Color] = [Color("dfceb1"), Color("a1bbcc"), Color("c0c7b1")]
## Extra clearance between a crossing flock and a car it might otherwise catch up with.
const SHEEP_CAR_MARGIN: float = 50.0
## Money moves with the road like sheep, so a flock starts only this far from any note.
const SHEEP_MONEY_GAP: float = 70.0

@export var sheep_settings: SheepSettings

var vehicles: Array[TrafficCar] = []
var difficulty_progress: float = 0.0
var near_miss_combo: int = 0
## "car" or "sheep": what ended the run, for the results message.
var last_contact_kind: String = "car"
var _road: RoadSettings
var _settings: TrafficSettings
var _distance_until_spawn: float = 0.0
var _next_lane: int = 0
var _random := RandomNumberGenerator.new()
var _vertical_padding: float = 0.0
var _pixels_since_near_miss: float = INF
var _metres: float = 0.0

@onready var sheep_crossing: SheepCrossing = $SheepCrossing


func configure(road: RoadSettings, settings: TrafficSettings) -> void:
	for vehicle in vehicles:
		remove_child(vehicle)
		vehicle.queue_free()
	vehicles.clear()
	_road = road
	_settings = settings
	assert(settings.difficulty_full_metres > settings.difficulty_start_metres)
	difficulty_progress = 0.0
	near_miss_combo = 0
	_pixels_since_near_miss = INF
	_metres = 0.0
	last_contact_kind = "car"
	sheep_crossing.configure(road, sheep_settings)
	_distance_until_spawn = settings.first_spawn_distance
	_next_lane = _random.randi_range(0, 1)


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


func set_distance(metres: float) -> void:
	_metres = metres
	difficulty_progress = clampf(
		inverse_lerp(_settings.difficulty_start_metres, _settings.difficulty_full_metres, metres),
		0.0,
		1.0
	)


## money_bounds: pickups on the road, so a new flock never starts level with a note.
## hazard_bounds: potholes and road works, so a new car never appears on top of one.
func advance(
	travel_pixels: float,
	player_bounds: Rect2,
	money_bounds: Array[Rect2] = [],
	hazard_bounds: Array[Rect2] = []
) -> void:
	var traffic_travel := travel_pixels * _settings.relative_speed
	var near_misses := 0
	for index in range(vehicles.size() - 1, -1, -1):
		var vehicle := vehicles[index]
		var previous_bounds := vehicle.collision_bounds()
		vehicle.advance(traffic_travel)
		# Sweep the vertical travel so a slow frame cannot skip a collision.
		var swept_bounds := previous_bounds.merge(vehicle.collision_bounds())
		if not vehicle.has_contacted and swept_bounds.intersects(player_bounds):
			# Keep the crashed car at contact, even when a long frame would carry it offscreen.
			vehicle.position.y = clampf(
				player_bounds.position.y - previous_bounds.size.y * 0.5,
				previous_bounds.get_center().y,
				vehicle.position.y
			)
			vehicle.mark_contacted()
			last_contact_kind = "car"
			contacted.emit()
			return
		if _track_pass(vehicle, swept_bounds, player_bounds):
			near_misses += 1
		if vehicle.position.y > _settings.despawn_y + _vertical_padding:
			vehicles.remove_at(index)
			vehicle.queue_free()
	var despawn := _settings.despawn_y + _vertical_padding
	if sheep_crossing.advance(travel_pixels, player_bounds, despawn):
		last_contact_kind = "sheep"
		contacted.emit()
		return
	if sheep_crossing.is_due(_metres) and _road_clear_for_sheep(money_bounds):
		sheep_crossing.start(_settings.spawn_y - _vertical_padding, _metres)
	# Awarded after the loop: a crash anywhere in this frame returns first and pays nothing.
	_pixels_since_near_miss += travel_pixels
	for _near_miss in range(near_misses):
		_award_near_miss()
	_distance_until_spawn -= travel_pixels
	if _distance_until_spawn <= 0.0 and _can_spawn(hazard_bounds):
		_spawn_vehicle()


func _track_pass(vehicle: TrafficCar, swept: Rect2, player_bounds: Rect2) -> bool:
	# Returns true once, when a car that came close has fully passed the player.
	if vehicle.has_passed:
		return false
	if swept.position.y < player_bounds.end.y and swept.end.y > player_bounds.position.y:
		var gap := maxf(
			player_bounds.position.x - swept.end.x, swept.position.x - player_bounds.end.x
		)
		vehicle.closest_gap = minf(vehicle.closest_gap, gap)
	if vehicle.collision_bounds().position.y < player_bounds.end.y:
		return false
	vehicle.has_passed = true
	return vehicle.closest_gap <= _settings.near_miss_gap


func _award_near_miss() -> void:
	if _pixels_since_near_miss > _settings.near_miss_combo_pixels:
		near_miss_combo = 0
	near_miss_combo = mini(near_miss_combo + 1, _settings.near_miss_max_combo)
	_pixels_since_near_miss = 0.0
	near_missed.emit(_settings.near_miss_points * near_miss_combo, near_miss_combo)


## A shield absorbed a crash: whatever was hit is knocked off the road.
func clear_contact() -> void:
	for index in range(vehicles.size() - 1, -1, -1):
		if vehicles[index].has_contacted:
			var vehicle := vehicles[index]
			vehicles.remove_at(index)
			remove_child(vehicle)
			vehicle.queue_free()
	sheep_crossing.clear_contact()


func _road_clear_for_sheep(money_bounds: Array[Rect2]) -> bool:
	# Sheep move with the road, faster than cars; start only if no car can be caught up with.
	var top := _settings.spawn_y - _vertical_padding
	for note in money_bounds:
		if absf(note.get_center().y - top) < SHEEP_MONEY_GAP:
			return false
	var bottom := _settings.despawn_y + _vertical_padding
	var speed := _settings.relative_speed
	var safe_y := (1.0 - speed) * bottom + speed * top + SHEEP_CAR_MARGIN
	for vehicle in vehicles:
		if vehicle.position.y < safe_y:
			return false
	return true


func _can_spawn(hazard_bounds: Array[Rect2]) -> bool:
	if vehicles.size() >= _settings.max_vehicles or sheep_crossing.is_due(_metres):
		return false
	var top := _settings.spawn_y - _vertical_padding
	var reach := _settings.collision_half_size.y + 20.0
	for hazard in hazard_bounds:
		if hazard.end.y > top - reach and hazard.position.y < top + reach:
			return false
	if sheep_crossing.top_y() - top < _settings.minimum_gap:
		return false
	for vehicle in vehicles:
		if vehicle.position.y - (_settings.spawn_y - _vertical_padding) < _settings.minimum_gap:
			return false
	return true


func blocking_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for vehicle in vehicles:
		bounds.append(vehicle.collision_bounds())
	var road_width := _road.right_edge - _road.left_edge
	for sheep in sheep_crossing.blocking_bounds():
		# Sheep walk across every lane, so money avoids the whole row, not just where they stand.
		bounds.append(Rect2(_road.left_edge, sheep.position.y, road_width, sheep.size.y))
	return bounds


func _spawn_vehicle() -> void:
	var vehicle := CAR_SCENE.instantiate() as TrafficCar
	vehicle.position = Vector2(
		_settings.lane_x(_road.left_edge, _road.right_edge, _next_lane, _random.randf()),
		_settings.spawn_y - _vertical_padding
	)
	add_child(vehicle)
	vehicle.configure(
		_settings.collision_half_size, PAINTS[_random.randi_range(0, PAINTS.size() - 1)]
	)
	vehicles.append(vehicle)
	_next_lane = 1 - _next_lane
	_distance_until_spawn = _random.randf_range(
		_settings.spawn_distance_min, _settings.spawn_distance_max
	)
	_distance_until_spawn *= lerpf(1.0, _settings.minimum_spawn_scale, difficulty_progress)

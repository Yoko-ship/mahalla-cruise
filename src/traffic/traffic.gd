class_name TrafficController
extends Node2D
## Spawns spaced vehicles and reports contact, without accessing the player or HUD.

signal contacted

const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const PAINTS: Array[Color] = [Color("dfceb1"), Color("a1bbcc"), Color("c0c7b1")]

var vehicles: Array[TrafficCar] = []
var difficulty_progress: float = 0.0
var _road: RoadSettings
var _settings: TrafficSettings
var _distance_until_spawn: float = 0.0
var _next_lane: int = 0
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings, settings: TrafficSettings) -> void:
	for vehicle in vehicles:
		remove_child(vehicle)
		vehicle.queue_free()
	vehicles.clear()
	_road = road
	_settings = settings
	assert(settings.difficulty_full_metres > settings.difficulty_start_metres)
	difficulty_progress = 0.0
	_distance_until_spawn = settings.first_spawn_distance
	_next_lane = _random.randi_range(0, 1)


func set_distance(metres: float) -> void:
	difficulty_progress = clampf(
		inverse_lerp(_settings.difficulty_start_metres, _settings.difficulty_full_metres, metres),
		0.0,
		1.0
	)


func advance(travel_pixels: float, player_bounds: Rect2) -> void:
	var traffic_travel := travel_pixels * _settings.relative_speed
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
			contacted.emit()
			return
		if vehicle.position.y > _settings.despawn_y:
			vehicles.remove_at(index)
			vehicle.queue_free()
	_distance_until_spawn -= travel_pixels
	if _distance_until_spawn <= 0.0 and _can_spawn():
		_spawn_vehicle()


func _can_spawn() -> bool:
	if vehicles.size() >= _settings.max_vehicles:
		return false
	for vehicle in vehicles:
		if vehicle.position.y - _settings.spawn_y < _settings.minimum_gap:
			return false
	return true


func blocking_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for vehicle in vehicles:
		bounds.append(vehicle.collision_bounds())
	return bounds


func _spawn_vehicle() -> void:
	var vehicle := CAR_SCENE.instantiate() as TrafficCar
	var lane_fraction := 0.25 if _next_lane == 0 else 0.75
	vehicle.position = Vector2(
		lerpf(_road.left_edge, _road.right_edge, lane_fraction), _settings.spawn_y
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

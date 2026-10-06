class_name PickupController
extends Node2D
## Spawns reachable money and signals collections; never reads siblings or the HUD.

signal collected(points: int, note: BanknoteDefinition)

const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const LANES: Array[float] = [0.25, 0.5, 0.75]

var items: Array[MoneyPickup] = []
var _road: RoadSettings
var _settings: PickupSettings
var _distance_until_spawn: float = 0.0
var _next_lane: int = 1
var _random := RandomNumberGenerator.new()
var _vertical_padding: float = 0.0


func configure(road: RoadSettings, settings: PickupSettings) -> void:
	for item in items:
		remove_child(item)
		item.queue_free()
	items.clear()
	_road = road
	_settings = settings
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
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		var previous := item.collection_bounds()
		item.advance(travel_pixels)
		if previous.merge(item.collection_bounds()).intersects(player_bounds):
			_remove_item(index)
			collected.emit(item.points, item.denomination)
		elif item.position.y > _settings.despawn_y + _vertical_padding:
			_remove_item(index)
	_distance_until_spawn = maxf(0.0, _distance_until_spawn - travel_pixels)
	if _distance_until_spawn <= 0.0 and items.size() < _settings.max_pickups:
		_try_spawn(player_bounds, traffic_bounds, traffic_speed_ratio)


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
	# New traffic behind a note cannot catch it because traffic moves more slowly.
	var spawn_y := _settings.spawn_y - _vertical_padding
	var travel_to_player := maxf(0.0, player_bounds.get_center().y - spawn_y)
	var half_width := maxf(player_bounds.size.x * 0.5, _settings.collision_half_size.x)
	for obstacle in traffic_bounds:
		if obstacle.end.x < x - half_width - 4.0 or obstacle.position.x > x + half_width + 4.0:
			continue
		var start_gap := obstacle.get_center().y - spawn_y
		var end_gap := start_gap - travel_to_player * (1.0 - traffic_speed_ratio)
		var clearance := _settings.traffic_clearance + obstacle.size.y * 0.5
		clearance += _settings.collision_half_size.y
		if minf(start_gap, end_gap) < clearance and maxf(start_gap, end_gap) > -clearance:
			return false
	return true

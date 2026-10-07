class_name SheepCrossing
extends Node2D
## Owns the current flock. The traffic controller decides when a crossing may start.

const SHEEP_SCENE: PackedScene = preload("res://src/traffic/sheep.tscn")
const SIDEWALK_OFFSET: float = 22.0

var flock: Array[Sheep] = []
var next_crossing_metres: float = 0.0
var _road: RoadSettings
var _settings: SheepSettings
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings, settings: SheepSettings) -> void:
	for sheep in flock:
		remove_child(sheep)
		sheep.queue_free()
	flock.clear()
	_road = road
	_settings = settings
	assert(settings.crossing_metres_max >= settings.crossing_metres_min)
	assert(settings.flock_size_max >= settings.flock_size_min)
	next_crossing_metres = settings.first_crossing_metres


func is_due(metres: float) -> bool:
	return flock.is_empty() and metres >= next_crossing_metres


func start(top_y: float, metres: float) -> void:
	var direction := 1.0 if _random.randf() < 0.5 else -1.0
	var start_edge := _road.left_edge if direction > 0.0 else _road.right_edge
	var stop_edge := _road.right_edge if direction > 0.0 else _road.left_edge
	var count := _random.randi_range(_settings.flock_size_min, _settings.flock_size_max)
	for index in range(count):
		var sheep := SHEEP_SCENE.instantiate() as Sheep
		# The leader walks first; followers trail behind it on the starting sidewalk.
		sheep.position = Vector2(
			start_edge - direction * (SIDEWALK_OFFSET + index * _settings.spacing),
			top_y + _random.randf_range(-_settings.row_jitter, _settings.row_jitter)
		)
		add_child(sheep)
		var stop_x := stop_edge + direction * (SIDEWALK_OFFSET + (count - 1 - index) * 18.0)
		sheep.configure(_settings.collision_half_size, direction, stop_x)
		flock.append(sheep)
	next_crossing_metres = (
		metres + _random.randf_range(_settings.crossing_metres_min, _settings.crossing_metres_max)
	)


## Returns true when a sheep touches the player; that sheep stays at the contact point.
func advance(travel_pixels: float, player_bounds: Rect2, despawn_y: float) -> bool:
	var walk := travel_pixels * _settings.walk_per_travel
	for index in range(flock.size() - 1, -1, -1):
		var sheep := flock[index]
		var previous := sheep.collision_bounds()
		sheep.advance(travel_pixels, walk)
		if (
			not sheep.has_contacted
			and previous.merge(sheep.collision_bounds()).intersects(player_bounds)
		):
			sheep.position.y = clampf(
				player_bounds.position.y - previous.size.y * 0.5,
				previous.get_center().y,
				sheep.position.y
			)
			sheep.mark_contacted()
			return true
		if sheep.position.y > despawn_y:
			flock.remove_at(index)
			sheep.queue_free()
	return false


func clear_contact() -> void:
	for index in range(flock.size() - 1, -1, -1):
		if flock[index].has_contacted:
			var sheep := flock[index]
			flock.remove_at(index)
			remove_child(sheep)
			sheep.queue_free()


func top_y() -> float:
	var top := INF
	for sheep in flock:
		top = minf(top, sheep.collision_bounds().position.y)
	return top


func blocking_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for sheep in flock:
		bounds.append(sheep.collision_bounds())
	return bounds

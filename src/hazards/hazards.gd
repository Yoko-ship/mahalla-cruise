class_name HazardController
extends Node2D
## Spawns potholes and road works near the centre line, clear of traffic, sheep rows, money,
## and the curbside refuel and boarding zones. Hitting one signals a point penalty upward.

signal hit(kind: String, penalty: int)

const HAZARD_SCENE: PackedScene = preload("res://src/hazards/road_hazard.tscn")

@export var settings: HazardSettings

var hazards: Array[RoadHazard] = []
## Suspension upgrades shrink penalties. Set between drives.
var penalty_scale: float = 1.0
var _road: RoadSettings
var _vertical_padding: float = 0.0
var _metres_until_hazard: float = 0.0
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings) -> void:
	assert(settings != null, "Hazards require HazardSettings")
	for hazard in hazards:
		remove_child(hazard)
		hazard.queue_free()
	hazards.clear()
	_road = road
	_metres_until_hazard = settings.first_metres


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


func penalty_for(kind: String) -> int:
	return roundi(settings.penalty(kind) * penalty_scale)


## traffic_bounds: cars and sheep rows; item_bounds: notes and power-ups.
func advance(
	travel_pixels: float,
	player_bounds: Rect2,
	traffic_bounds: Array[Rect2],
	item_bounds: Array[Rect2],
	traffic_speed_ratio: float
) -> void:
	for index in range(hazards.size() - 1, -1, -1):
		var hazard := hazards[index]
		var previous := hazard.collision_bounds()
		hazard.advance(travel_pixels)
		if (
			not hazard.is_hit
			and previous.merge(hazard.collision_bounds()).intersects(player_bounds)
		):
			hazard.mark_hit()
			hit.emit(hazard.kind, penalty_for(hazard.kind))
		if hazard.position.y > settings.despawn_y + _vertical_padding:
			hazards.remove_at(index)
			remove_child(hazard)
			hazard.queue_free()
	_metres_until_hazard -= travel_pixels / _road.pixels_per_metre
	if _metres_until_hazard <= 0.0:
		_try_spawn(player_bounds, traffic_bounds, item_bounds, traffic_speed_ratio)


func item_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for hazard in hazards:
		bounds.append(hazard.collision_bounds())
	return bounds


func _try_spawn(
	player_bounds: Rect2,
	traffic_bounds: Array[Rect2],
	item_bounds: Array[Rect2],
	traffic_speed_ratio: float
) -> void:
	var spawn_y := settings.spawn_y - _vertical_padding
	for item in item_bounds:
		if absf(item.get_center().y - spawn_y) < settings.item_gap:
			return
	var kind := "works" if _random.randf() < settings.works_chance else "pothole"
	var half := settings.half_size(kind)
	var x := (_road.left_edge + _road.right_edge) * 0.5
	if kind == "pothole":
		x += _random.randf_range(-settings.centre_spread, settings.centre_spread)
	# Potholes lie flat, so cars may drive over them; a barrier must stay clear of their path.
	var target_y := player_bounds.get_center().y
	var clearance := settings.traffic_clearance
	if (
		kind == "works"
		and not RoadPath.is_clear(
			x, spawn_y, half, target_y, traffic_bounds, traffic_speed_ratio, clearance
		)
	):
		return
	var hazard := HAZARD_SCENE.instantiate() as RoadHazard
	hazard.position = Vector2(x, spawn_y)
	add_child(hazard)
	hazard.configure(kind, half)
	hazards.append(hazard)
	_metres_until_hazard = _random.randf_range(settings.spawn_metres_min, settings.spawn_metres_max)

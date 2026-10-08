class_name PoliceController
extends Node2D
## One YHXB (GAI) post at a time on the left curb. When the officer waves, pulling into
## the bay at or below the stop speed is a stop (reward); passing the bay without one is
## a fine. Signals upward; never reads siblings or the HUD.

signal warned
signal cleared(points: int)
signal fined(points: int)

const POST_SCENE: PackedScene = preload("res://src/police/police_post.tscn")

@export var settings: PoliceSettings

var posts: Array[PolicePost] = []
var _road: RoadSettings
var _vertical_padding: float = 0.0
var _metres_until_post: float = 0.0
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings) -> void:
	assert(settings != null, "Police require PoliceSettings")
	for post in posts:
		remove_child(post)
		post.queue_free()
	posts.clear()
	_road = road
	_metres_until_post = settings.first_metres


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


## A post on screen holds the left curb; METAN stations wait meanwhile.
func is_busy() -> bool:
	return not posts.is_empty()


## The stop speed while a waving officer is ahead, or 0.
func active_limit() -> int:
	for post in posts:
		if post.waving and not post.is_done:
			return settings.stop_kmh
	return 0


## curb_clear: no METAN station is on the left curb, so a post may appear.
func advance(travel_pixels: float, player_bounds: Rect2, speed_kmh: int, curb_clear: bool) -> void:
	for index in range(posts.size() - 1, -1, -1):
		var post := posts[index]
		var previous := post.stop_zone(settings.stop_distance)
		post.advance(travel_pixels)
		var zone := previous.merge(post.stop_zone(settings.stop_distance))
		if post.waving and not post.is_done:
			if zone.intersects(player_bounds) and speed_kmh <= settings.stop_kmh:
				post.finish()
				cleared.emit(settings.reward_points)
			elif previous.position.y > player_bounds.end.y:
				post.finish()
				fined.emit(settings.fine_points)
		if post.position.y > settings.despawn_y + _vertical_padding:
			posts.remove_at(index)
			remove_child(post)
			post.queue_free()
	_metres_until_post -= travel_pixels / _road.pixels_per_metre
	if _metres_until_post <= 0.0 and posts.is_empty() and curb_clear:
		_spawn()


func _spawn() -> void:
	var post := POST_SCENE.instantiate() as PolicePost
	post.position = Vector2(_road.left_edge, settings.spawn_y - _vertical_padding)
	add_child(post)
	var wave := _random.randf() < settings.wave_chance
	post.configure(wave, settings.zone_height, settings.stop_distance)
	posts.append(post)
	_metres_until_post = _random.randf_range(settings.spawn_metres_min, settings.spawn_metres_max)
	if wave:
		warned.emit()

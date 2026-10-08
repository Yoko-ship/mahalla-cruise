class_name SpeedCameraController
extends Node2D
## Spawns one speed camera at a time and checks the car's speed as it passes under the
## gantry. Above the limit it flashes and signals a fine; never reads siblings or the HUD.

signal warned(limit_kmh: int)
signal fined(points: int)
signal passed_clean

const CAMERA_SCENE: PackedScene = preload("res://src/cameras/speed_camera.tscn")

@export var settings: SpeedCameraSettings

var cameras: Array[SpeedCamera] = []
var _road: RoadSettings
var _vertical_padding: float = 0.0
var _metres_until_camera: float = 0.0
var _random := RandomNumberGenerator.new()


func configure(road: RoadSettings) -> void:
	assert(settings != null and not settings.limits_kmh.is_empty(), "Cameras require settings")
	for camera in cameras:
		remove_child(camera)
		camera.queue_free()
	cameras.clear()
	_road = road
	_metres_until_camera = settings.first_metres


func set_vertical_padding(pixels: float) -> void:
	_vertical_padding = maxf(0.0, pixels)


## The limit of the camera ahead, or 0 when none is waiting.
func active_limit() -> int:
	for camera in cameras:
		if not camera.is_passed:
			return camera.limit_kmh
	return 0


## player_y: the car's centre line; speed_kmh: what the speedometer shows this frame.
func advance(travel_pixels: float, player_y: float, speed_kmh: int) -> void:
	for index in range(cameras.size() - 1, -1, -1):
		var camera := cameras[index]
		var previous_y := camera.position.y
		camera.advance(travel_pixels, _road.pixels_per_metre)
		if not camera.is_passed and previous_y < player_y and camera.position.y >= player_y:
			camera.pass_under()
			if speed_kmh > camera.limit_kmh:
				camera.flash()
				fined.emit(settings.fine_for(speed_kmh, camera.limit_kmh))
			else:
				passed_clean.emit()
		if camera.position.y > settings.despawn_y + _vertical_padding:
			cameras.remove_at(index)
			remove_child(camera)
			camera.queue_free()
	_metres_until_camera -= travel_pixels / _road.pixels_per_metre
	if _metres_until_camera <= 0.0 and cameras.is_empty():
		_spawn()


func _spawn() -> void:
	var camera := CAMERA_SCENE.instantiate() as SpeedCamera
	# The painted limit enters first; the gantry follows above it.
	var gantry_y := settings.spawn_y - _vertical_padding - settings.marking_offset
	camera.position = Vector2((_road.left_edge + _road.right_edge) * 0.5, gantry_y)
	add_child(camera)
	var limits := settings.limits_kmh
	camera.configure(
		limits[_random.randi_range(0, limits.size() - 1)],
		(_road.right_edge - _road.left_edge) * 0.5,
		settings.marking_offset,
		settings.flash_metres
	)
	cameras.append(camera)
	_metres_until_camera = _random.randf_range(settings.spawn_metres_min, settings.spawn_metres_max)
	warned.emit(camera.limit_kmh)

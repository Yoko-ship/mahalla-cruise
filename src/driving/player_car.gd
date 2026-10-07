class_name PlayerCar
extends Node2D
## Owns steering state and movement. Input and visuals are child components.

@export var settings: CarSettings

var left_limit: float = 0.0
var right_limit: float = 0.0
var target_x: float = 0.0
var _driving_enabled: bool = true

@onready var steering: SteeringInput = $SteeringInput
@onready var visual: CarVisual = $Visual


func _ready() -> void:
	assert(settings != null, "Player scene requires CarSettings")
	target_x = position.x
	steering.steering_delta.connect(_on_steering_delta)


func apply_car(
	car_settings: CarSettings, texture: Texture2D, sprite_scale: float, paint: Color
) -> void:
	# Call configure_bounds() afterwards; the road margin can differ between cars.
	settings = car_settings
	visual.set_vehicle(texture, sprite_scale, paint)


func configure_bounds(road_left: float, road_right: float) -> void:
	left_limit = road_left + settings.road_margin
	right_limit = road_right - settings.road_margin
	assert(left_limit <= right_limit, "Car must fit inside the road")
	target_x = clampf(position.x, left_limit, right_limit)
	position.x = target_x


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _driving_enabled:
		return
	var keyboard_move := steering.keyboard_axis() * settings.steering_speed * delta
	target_x = clampf(target_x + keyboard_move, left_limit, right_limit)
	var previous_x := position.x
	position.x = move_toward(position.x, target_x, settings.steering_speed * delta)
	var lean := clampf(
		(position.x - previous_x) * settings.lean_per_pixel, -settings.max_lean, settings.max_lean
	)
	rotation = lerpf(rotation, lean, 1.0 - exp(-settings.lean_response * delta))


func _on_steering_delta(pixels: float) -> void:
	if not _driving_enabled:
		return
	target_x = clampf(target_x + pixels * settings.drag_sensitivity, left_limit, right_limit)


func collision_bounds() -> Rect2:
	return Rect2(position - settings.collision_half_size, settings.collision_half_size * 2.0)


func set_driving_enabled(enabled: bool) -> void:
	_driving_enabled = enabled
	steering.set_enabled(enabled)
	set_physics_process(enabled)
	target_x = position.x


func reset_run(start_position: Vector2) -> void:
	position = start_position
	rotation = 0.0
	set_driving_enabled(true)

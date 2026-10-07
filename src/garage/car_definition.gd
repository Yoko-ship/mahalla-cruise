class_name CarDefinition
extends Resource
## One garage car: identity, price, handling, and artwork. Read-only during play.

const SPEED_RANGE := Vector2(0.8, 1.3)
const CONTROL_RANGE := Vector2(480.0, 880.0)
const SIZE_RANGE := Vector2(450.0, 850.0)

@export var id: String = ""
## Model names stay untranslated, like the language names in the menu.
@export var display_name: String = ""
@export_range(0, 1000000) var price: int = 0
@export var settings: CarSettings
## Leave empty until approved artwork exists; cars without artwork stay hidden.
@export var texture: Texture2D
@export_range(0.01, 1.0) var sprite_scale: float = 0.116


func is_available() -> bool:
	return texture != null and settings != null


func speed_rating() -> float:
	return _rating(settings.travel_speed_scale, SPEED_RANGE)


func control_rating() -> float:
	return _rating(settings.steering_speed, CONTROL_RANGE)


func size_rating() -> float:
	return _rating(settings.collision_half_size.x * settings.collision_half_size.y, SIZE_RANGE)


func _rating(value: float, range_limits: Vector2) -> float:
	return clampf(inverse_lerp(range_limits.x, range_limits.y, value), 0.0, 1.0)

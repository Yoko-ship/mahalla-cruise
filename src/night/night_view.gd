class_name NightView
extends Node2D
## Darkens the street once night falls, with headlights and street lamps, and owns the
## night points bonus. Draws one shaded rectangle over the visible street.

signal fell(bonus_percent: int)

const SHADER: Shader = preload("res://src/night/night.gdshader")

@export var settings: NightSettings

## 0 by day, 1 when fully dark.
var amount: float = 0.0
var _view_bounds := Rect2(0, 0, 432, 768)
var _lamp_offset: float = 0.0
var _announced: bool = false
var _shade := ShaderMaterial.new()


func _ready() -> void:
	assert(settings != null, "Night requires NightSettings")
	_shade.shader = SHADER
	material = _shade
	_shade.set_shader_parameter("tint", settings.tint)
	_shade.set_shader_parameter("beam_length", settings.beam_length)
	_shade.set_shader_parameter("lamp_spacing", settings.lamp_spacing)


func configure(road: RoadSettings) -> void:
	amount = 0.0
	_lamp_offset = 0.0
	_announced = false
	_shade.set_shader_parameter("lamp_x", Vector2(road.left_edge - 14.0, road.right_edge + 14.0))
	_apply(Vector2.ZERO)


func set_view_bounds(bounds: Rect2) -> void:
	_view_bounds = bounds
	queue_redraw()


func advance(travel_pixels: float, metres: float, car_position: Vector2) -> void:
	_lamp_offset = fposmod(_lamp_offset + travel_pixels, settings.lamp_spacing)
	amount = clampf((metres - settings.start_metres) / settings.dusk_metres, 0.0, 1.0)
	_apply(car_position)
	if amount >= 1.0 and not _announced:
		_announced = true
		fell.emit(settings.bonus_percent)


## Money and close-call points earn the bonus only once it is fully dark.
func bonus(points: int) -> int:
	if amount < 1.0 or points <= 0:
		return points
	return points + ceili(points * settings.bonus_percent / 100.0)


func _apply(car_position: Vector2) -> void:
	visible = amount > 0.0
	_shade.set_shader_parameter("darkness", amount * settings.darkness)
	_shade.set_shader_parameter("car", car_position)
	_shade.set_shader_parameter("lamp_offset", _lamp_offset)


func _draw() -> void:
	draw_rect(_view_bounds, Color.WHITE)

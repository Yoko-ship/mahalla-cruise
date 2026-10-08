class_name SpeedCamera
extends Node2D
## One speed camera: the limit painted on the asphalt ahead and the gantry's shadow. The
## gantry itself is a child drawn above the cars. Drawn in code (temporary art).

const PAINT := Color(0.96, 0.95, 0.9, 0.9)
const RING := Color(0.84, 0.18, 0.15, 0.9)
const NUMBER := Color(0.1, 0.1, 0.1, 0.95)
const SHADOW := Color(0.05, 0.06, 0.05, 0.22)

var limit_kmh: int = 40
var is_passed: bool = false
var _half_width: float = 92.0
var _marking_offset: float = 150.0
var _flash_metres: float = 8.0
var _flash_left: float = 0.0

@onready var gantry: SpeedCameraGantry = $Gantry


func configure(limit: int, half_width: float, marking_offset: float, flash_metres: float) -> void:
	limit_kmh = limit
	_half_width = half_width
	_marking_offset = marking_offset
	_flash_metres = flash_metres
	gantry.configure(half_width)
	queue_redraw()


func advance(travel_pixels: float, pixels_per_metre: float) -> void:
	position.y += travel_pixels
	_flash_left = maxf(0.0, _flash_left - travel_pixels / pixels_per_metre)
	gantry.advance(travel_pixels, _flash_left / _flash_metres)


func pass_under() -> void:
	is_passed = true


func flash() -> void:
	_flash_left = _flash_metres
	gantry.advance(0.0, 1.0)


func is_flashing() -> bool:
	return _flash_left > 0.0


func _draw() -> void:
	draw_rect(Rect2(-_half_width - 14.0, 9, _half_width * 2.0 + 28.0, 12), SHADOW)
	var mark := Vector2(0, _marking_offset)
	draw_circle(mark, 21.0, PAINT)
	draw_arc(mark, 19.0, 0.0, TAU, 32, RING, 5.0)
	draw_string(
		ThemeDB.fallback_font,
		mark + Vector2(-16, 6),
		str(limit_kmh),
		HORIZONTAL_ALIGNMENT_CENTER,
		32,
		17,
		NUMBER
	)

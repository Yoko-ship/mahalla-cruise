class_name Speedometer
extends Control
## Current speed in km/h. While a speed camera is ahead it shows the limit sign, and the
## speed turns red above it.

const BACKGROUND := Color(0.21, 0.23, 0.19, 0.9)
const BORDER := Color(0.88, 0.84, 0.7, 0.7)
const TEXT := Color(1, 0.96, 0.85, 1)
const OVER := Color(1, 0.42, 0.33, 1)
const SIGN := Color(0.97, 0.96, 0.92, 1)
const RING := Color(0.84, 0.18, 0.15, 1)
const INK := Color(0.1, 0.1, 0.1, 1)
const SIGN_RADIUS: float = 17.0

var speed_kmh: int = 0
var limit_kmh: int = 0
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.bg_color = BACKGROUND
	_box.border_color = BORDER
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(14)


## limit 0 hides the sign.
func set_speed(speed: int, limit: int) -> void:
	if speed == speed_kmh and limit == limit_kmh:
		return
	speed_kmh = speed
	limit_kmh = limit
	queue_redraw()


func is_over_limit() -> bool:
	return limit_kmh > 0 and speed_kmh > limit_kmh


func refresh_text() -> void:
	queue_redraw()


func _draw() -> void:
	var panel := Rect2(0, 0, size.x - SIGN_RADIUS * 2.0 - 6.0, size.y)
	draw_style_box(_box, panel)
	var font := get_theme_default_font()
	var colour := OVER if is_over_limit() else TEXT
	draw_string(
		font, Vector2(0, 27), str(speed_kmh), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, colour
	)
	draw_string(
		font, Vector2(0, size.y - 7), tr("kmh"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 11, TEXT
	)
	if limit_kmh <= 0:
		return
	var centre := Vector2(size.x - SIGN_RADIUS - 1.0, size.y * 0.5)
	draw_circle(centre, SIGN_RADIUS, SIGN)
	draw_arc(centre, SIGN_RADIUS - 2.5, 0.0, TAU, 32, RING, 5.0)
	var number := str(limit_kmh)
	draw_string(
		font,
		centre + Vector2(-SIGN_RADIUS, 5),
		number,
		HORIZONTAL_ALIGNMENT_CENTER,
		SIGN_RADIUS * 2.0,
		14,
		INK
	)

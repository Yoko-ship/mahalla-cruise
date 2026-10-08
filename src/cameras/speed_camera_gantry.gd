class_name SpeedCameraGantry
extends Node2D
## The overhead gantry: posts on both sidewalks, a steel beam, a blue camera sign, two
## cameras over the lanes with blinking lights, and the white flash when one fires.

const STEEL := Color("6b7178")
const STEEL_LIGHT := Color("a3aab1")
const STEEL_DARK := Color("3e4247")
const SIGN := Color("2f5fa8")
const HOUSING := Color("e4e4dc")
const LENS := Color("1b2024")
const LIGHT_ON := Color("ff3b2f")
const LIGHT_OFF := Color("6e2a26")
const BLINK_PIXELS: float = 70.0

var _half_width: float = 92.0
var _blink: float = 0.0
var _flash: float = 0.0


func configure(half_width: float) -> void:
	_half_width = half_width
	queue_redraw()


## flash is the share of the flash still showing (1 when it fires).
func advance(travel_pixels: float, flash: float) -> void:
	_blink = fposmod(_blink + travel_pixels, BLINK_PIXELS)
	_flash = flash
	queue_redraw()


func _draw() -> void:
	var span := _half_width + 14.0
	for side: float in [-1.0, 1.0]:
		var post := Vector2(side * span, 0)
		draw_rect(Rect2(post + Vector2(-6, -6), Vector2(12, 12)), STEEL_DARK)
		draw_rect(Rect2(post + Vector2(-4, -4), Vector2(8, 8)), STEEL)
	draw_rect(Rect2(-span, -5, span * 2.0, 10), STEEL)
	draw_line(Vector2(-span, -5), Vector2(span, -5), STEEL_LIGHT, 2.0)
	draw_line(Vector2(-span, 5), Vector2(span, 5), STEEL_DARK, 1.5)
	_draw_sign()
	var light_on := _blink < BLINK_PIXELS * 0.5
	for side: float in [-1.0, 1.0]:
		var camera := Vector2(side * _half_width * 0.5, 0)
		draw_rect(Rect2(camera + Vector2(-9, 2), Vector2(18, 14)), STEEL_DARK)
		draw_rect(Rect2(camera + Vector2(-8, 2), Vector2(16, 12)), HOUSING)
		draw_circle(camera + Vector2(0, 14), 4.5, LENS)
		draw_circle(camera + Vector2(-1.5, 12.5), 1.2, Color(1, 1, 1, 0.7))
		draw_circle(camera + Vector2(6, 5), 2.0, LIGHT_ON if light_on else LIGHT_OFF)
		if _flash > 0.0:
			draw_circle(camera + Vector2(0, 16), 34.0, Color(1, 1, 0.94, 0.3 * _flash))
			draw_circle(camera + Vector2(0, 16), 16.0, Color(1, 1, 1, 0.85 * _flash))


func _draw_sign() -> void:
	draw_rect(Rect2(-17, -21, 34, 17), SIGN)
	draw_rect(Rect2(-17, -21, 34, 17), Color(1, 1, 1, 0.8), false, 1.0)
	# A white camera pictogram: body, lens, and viewfinder.
	draw_rect(Rect2(-8, -16, 16, 9), Color.WHITE)
	draw_rect(Rect2(-4, -18, 6, 2), Color.WHITE)
	draw_circle(Vector2(0, -11.5), 3.0, SIGN)
	draw_circle(Vector2(0, -11.5), 1.6, Color.WHITE)

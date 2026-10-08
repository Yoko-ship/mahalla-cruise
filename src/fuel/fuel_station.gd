class_name FuelStation
extends Node2D
## A METAN station on the left sidewalk, placed at the curb. Drawn in code (temporary art):
## a pad with pumps, a canopy edge, a sign, and a painted bay showing where to pull in.

const CANOPY := Color("2f8a57")
const PAD := Color("c9c2b0")
const PUMP := Color("3d6fa6")
const SCREEN := Color("dff3ff")
const POST := Color("3a3f3c")
const SIGN_TEXT := Color("f4f1e6")
const BAY := Color(1.0, 0.86, 0.35, 0.22)
const BAY_EDGE := Color(1.0, 0.9, 0.5, 0.7)

var is_open: bool = true
var _zone_height: float = 80.0
var _bay_width: float = 18.0


func configure(zone_height: float, bay_width: float) -> void:
	_zone_height = zone_height
	_bay_width = bay_width
	queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels


## The road strip beside the station, starting at the curb, where a car must be to refuel.
func refuel_zone(distance: float) -> Rect2:
	return Rect2(position.x, position.y - _zone_height * 0.5, distance, _zone_height)


func serve() -> void:
	is_open = false
	queue_redraw()


func _draw() -> void:
	if is_open:
		var bay := Rect2(0, -_zone_height * 0.5, _bay_width + 22.0, _zone_height)
		draw_rect(bay, BAY)
		draw_rect(bay, BAY_EDGE, false, 2.0)
	draw_rect(Rect2(-74, -34, 68, 68), PAD)
	for y: float in [-14.0, 12.0]:
		draw_rect(Rect2(-40, y - 7, 13, 15), PUMP)
		draw_rect(Rect2(-38, y - 5, 9, 4), SCREEN)
		draw_line(Vector2(-27, y + 2), Vector2(-12, y + 6), POST, 1.5)
	draw_rect(Rect2(-78, -42, 72, 9), CANOPY)
	draw_rect(Rect2(-68, -70, 3, 28), POST)
	draw_rect(Rect2(-80, -84, 58, 17), CANOPY)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-78, -71),
		"METAN",
		HORIZONTAL_ALIGNMENT_CENTER,
		54,
		12,
		SIGN_TEXT
	)

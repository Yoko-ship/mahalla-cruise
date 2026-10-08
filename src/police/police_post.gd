class_name PolicePost
extends Node2D
## A YHXB (GAI) post at the left curb: a white-and-blue booth, an officer in a reflective
## vest, and, when the officer waves drivers over, a raised striped baton and a painted
## stop bay. Drawn in code (temporary art). The controller decides what counts as a stop.

const BOOTH := Color("f1f1ec")
const BOOTH_STRIPE := Color("2457a6")
const ROOF := Color("8a9298")
const UNIFORM := Color("4d5a3c")
const VEST := Color("d9f24a")
const SKIN := Color("c98f63")
const CAP := Color("2f3a2a")
const BATON_DARK := Color("1d1d1d")
const BAY := Color(1, 1, 1, 0.75)

var waving: bool = false
## Stopped or driven past: the post has no more to say.
var is_done: bool = false
var _zone_height: float = 90.0
var _bay_width: float = 18.0


func configure(wave: bool, zone_height: float, bay_width: float) -> void:
	waving = wave
	_zone_height = zone_height
	_bay_width = bay_width
	queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels


## The road strip beside the post, starting at the curb, where the car must stop.
func stop_zone(distance: float) -> Rect2:
	return Rect2(position.x, position.y - _zone_height * 0.5, distance, _zone_height)


func finish() -> void:
	is_done = true
	queue_redraw()


func _draw() -> void:
	if waving and not is_done:
		var bay := Rect2(2, -_zone_height * 0.5, _bay_width + 22.0, _zone_height)
		for side in [bay.position.y, bay.end.y]:
			for step in range(4):
				var x := bay.position.x + step * bay.size.x / 4.0
				draw_line(Vector2(x, side), Vector2(x + bay.size.x / 8.0, side), BAY, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(bay.position.x, bay.get_center().y + 4),
			"STOP",
			HORIZONTAL_ALIGNMENT_CENTER,
			bay.size.x,
			11,
			BAY
		)
	_draw_booth(Vector2(-58, -18))
	_draw_officer(Vector2(-12, 14))


func _draw_booth(corner: Vector2) -> void:
	draw_rect(Rect2(corner + Vector2(4, 5), Vector2(38, 44)), Color(0.08, 0.08, 0.07, 0.22))
	draw_rect(Rect2(corner, Vector2(38, 44)), BOOTH)
	draw_rect(Rect2(corner + Vector2(0, 14), Vector2(38, 8)), BOOTH_STRIPE)
	draw_rect(Rect2(corner + Vector2(-3, -6), Vector2(44, 8)), ROOF)
	draw_rect(Rect2(corner + Vector2(5, 26), Vector2(28, 12)), Color("9cc3d8"))
	draw_string(
		ThemeDB.fallback_font,
		corner + Vector2(0, 21),
		"YHXB",
		HORIZONTAL_ALIGNMENT_CENTER,
		38,
		8,
		Color.WHITE
	)


func _draw_officer(foot: Vector2) -> void:
	draw_set_transform(foot, 0.0, Vector2(1.8, 1.8))
	draw_circle(Vector2(2, 1), 4.5, Color(0.1, 0.12, 0.1, 0.22))
	draw_rect(Rect2(-3.5, -13, 7, 12), UNIFORM)
	draw_rect(Rect2(-3.5, -12, 7, 6), VEST)
	draw_circle(Vector2(0, -16), 3.3, SKIN)
	draw_rect(Rect2(-4, -21, 8, 3), CAP)
	if waving and not is_done:
		# The baton points up and out over the road.
		var hand := Vector2(7, -20)
		draw_line(Vector2(3, -10), hand, UNIFORM, 2.5)
		for step in range(4):
			var from := hand + Vector2(1.5, -3) * step
			draw_line(
				from, from + Vector2(1.5, -3), Color.WHITE if step % 2 == 0 else BATON_DARK, 2.2
			)
	else:
		draw_line(Vector2(3, -10), Vector2(4, -3), UNIFORM, 2.5)
	draw_set_transform(Vector2.ZERO)

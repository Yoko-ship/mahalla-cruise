class_name TaxiSpot
extends Node2D
## A taxi passenger hailing at the right curb, or the drop-off bay they asked for. Drawn in
## code (temporary art): a waving figure with a TAKSI bubble, or a pin beside a green bay.

const HAIL_BAY := Color(1.0, 0.82, 0.2, 0.2)
const HAIL_EDGE := Color(1.0, 0.85, 0.3, 0.75)
const DROP_BAY := Color(0.3, 0.85, 0.45, 0.22)
const DROP_EDGE := Color(0.45, 0.95, 0.55, 0.8)
const PIN := Color("e5483b")
const SKIN := Color("c98f63")
const COAT := Color("3f6fb5")
const HAIR := Color("263c32")
const BUBBLE := Color("f6c933")
const INK := Color("1d1f1c")

var is_drop_off: bool = false
## A hail is served when the passenger boards; a drop-off when they get out.
var is_served: bool = false
var curb_x: float = 0.0
var _zone_height: float = 64.0
var _bay_width: float = 18.0


func configure(drop_off: bool, curb: float, zone_height: float, bay_width: float) -> void:
	is_drop_off = drop_off
	curb_x = curb
	_zone_height = zone_height
	_bay_width = bay_width
	queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels


## The road strip beside the spot, ending at the curb, where the car must pull in.
func zone(board_distance: float) -> Rect2:
	var top := position.y - _zone_height * 0.5
	return Rect2(curb_x - board_distance, top, board_distance, _zone_height)


func serve() -> void:
	is_served = true
	queue_redraw()


func _draw() -> void:
	var local_curb := curb_x - position.x
	if not is_served:
		var width := _bay_width + 22.0
		var bay := Rect2(local_curb - width, -_zone_height * 0.5, width, _zone_height)
		draw_rect(bay, DROP_BAY if is_drop_off else HAIL_BAY)
		draw_rect(bay, DROP_EDGE if is_drop_off else HAIL_EDGE, false, 2.0)
	draw_set_transform(Vector2(local_curb, 0), 0.0, Vector2(1.35, 1.35))
	if is_drop_off:
		_draw_pin(Vector2(16, -8))
		if is_served:
			_draw_person(Vector2(26, 14), false)
	elif not is_served:
		_draw_person(Vector2(14, 12), true)
		_draw_bubble(Vector2(10, -42))


func _draw_person(foot: Vector2, waving: bool) -> void:
	draw_circle(foot + Vector2(2, 1), 4.0, Color(0.1, 0.12, 0.1, 0.2))
	draw_rect(Rect2(foot + Vector2(-3, -12), Vector2(6, 11)), COAT)
	draw_circle(foot + Vector2(0, -15), 3.2, SKIN)
	draw_rect(Rect2(foot + Vector2(-3, -19), Vector2(6, 2.5)), HAIR)
	if waving:
		# The arm toward the road is raised to hail.
		draw_line(foot + Vector2(-3, -10), foot + Vector2(-9, -22), COAT, 2.5)
		draw_circle(foot + Vector2(-9, -23), 1.8, SKIN)


func _draw_bubble(corner: Vector2) -> void:
	draw_rect(Rect2(corner, Vector2(30, 13)), BUBBLE)
	draw_rect(Rect2(corner, Vector2(30, 13)), INK, false, 1.0)
	draw_colored_polygon(
		PackedVector2Array(
			[corner + Vector2(6, 13), corner + Vector2(12, 13), corner + Vector2(5, 18)]
		),
		BUBBLE
	)
	draw_string(
		ThemeDB.fallback_font,
		corner + Vector2(1, 10),
		"TAKSI",
		HORIZONTAL_ALIGNMENT_CENTER,
		28,
		8,
		INK
	)


func _draw_pin(tip: Vector2) -> void:
	var head := tip + Vector2(0, -16)
	draw_colored_polygon(
		PackedVector2Array([tip, head + Vector2(-6, 3), head + Vector2(6, 3)]), PIN
	)
	draw_circle(head, 7.0, PIN)
	draw_circle(head, 2.8, Color.WHITE)
	draw_circle(tip + Vector2(1, 1), 3.0, Color(0.1, 0.12, 0.1, 0.25))

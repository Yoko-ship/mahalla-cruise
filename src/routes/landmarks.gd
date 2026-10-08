class_name LandmarkView
extends Node2D
## City landmarks on the sidewalks, drawn in code as temporary art until each city has a
## painted street: Registan-style portals (Samarkand), the Kalyan minaret (Bukhara), and
## Itchan Kala walls with Kalta Minor (Khiva). Scrolls with the road; no gameplay effect.

const SPACING: float = 620.0
## Distance from a curb to the centre of a landmark on that sidewalk.
const CURB_OFFSET: float = 60.0
const SAND := Color("dcbd86")
const SAND_DARK := Color("b8935c")
const BRICK := Color("c4925a")
const BRICK_DARK := Color("9c6a3c")
const TILE_BLUE := Color("2b62a6")
const TURQUOISE := Color("2f9fb3")
const TURQUOISE_DARK := Color("1f7486")
const CREAM := Color("eadbb0")
const ARCH := Color("3a2b22")
const SHADOW := Color(0.08, 0.07, 0.05, 0.22)

var kind: String = ""
var scroll_offset: float = 0.0
var _road: RoadSettings
var _view_bounds := Rect2(0, 0, 432, 768)


func configure(road: RoadSettings, landmarks: String) -> void:
	_road = road
	kind = landmarks
	scroll_offset = 0.0
	visible = not kind.is_empty()
	queue_redraw()


func advance(travel_pixels: float) -> void:
	if kind.is_empty():
		return
	scroll_offset = fposmod(scroll_offset + travel_pixels, SPACING * 2.0)
	queue_redraw()


func set_view_bounds(bounds: Rect2) -> void:
	_view_bounds = bounds
	queue_redraw()


func _draw() -> void:
	if _road == null or kind.is_empty():
		return
	var first := floori((_view_bounds.position.y - 200.0 - scroll_offset) / SPACING)
	var last := ceili((_view_bounds.end.y + 200.0 - scroll_offset) / SPACING)
	for index in range(first, last + 1):
		var y := index * SPACING + scroll_offset
		# Alternate sidewalks so each side keeps its shops and stations in between.
		var left := posmod(index, 2) == 0
		var x := _road.left_edge - CURB_OFFSET if left else _road.right_edge + CURB_OFFSET
		draw_set_transform(Vector2(x, y))
		match kind:
			"registan":
				_draw_registan()
			"kalyan":
				_draw_kalyan()
			"itchan_kala":
				_draw_itchan_kala()
	draw_set_transform(Vector2.ZERO)


func _draw_registan() -> void:
	draw_rect(Rect2(-54, -86, 108, 176), SAND_DARK)
	draw_rect(Rect2(-50, -82, 100, 168), SAND)
	_draw_dome(Vector2(0, -50), 30.0)
	draw_rect(Rect2(-38, -14, 82, 72), SHADOW)
	draw_rect(Rect2(-40, -18, 80, 70), CREAM)
	draw_rect(Rect2(-40, -18, 80, 70), TILE_BLUE, false, 4.0)
	_draw_arch(Rect2(-17, -6, 34, 52), ARCH)
	_draw_arch(Rect2(-13, -2, 26, 44), TILE_BLUE.darkened(0.3))
	for side: float in [-1.0, 1.0]:
		_draw_minaret(Vector2(side * 44, 62), 10.0)


func _draw_kalyan() -> void:
	draw_rect(Rect2(-54, -90, 108, 180), BRICK_DARK)
	draw_rect(Rect2(-50, -86, 100, 172), BRICK.lightened(0.15))
	_draw_dome(Vector2(-6, -52), 26.0)
	draw_circle(Vector2(6, 40), 33.0, SHADOW)
	draw_circle(Vector2(0, 34), 30.0, BRICK_DARK)
	draw_circle(Vector2(0, 34), 26.0, BRICK)
	for ring: float in [21.0, 15.0]:
		draw_arc(Vector2(0, 34), ring, 0.0, TAU, 24, BRICK_DARK, 2.0)
	for step in range(12):
		var angle := TAU * step / 12.0
		draw_circle(Vector2(0, 34) + Vector2.from_angle(angle) * 18.0, 1.6, TURQUOISE)
	draw_circle(Vector2(0, 34), 9.0, CREAM)
	draw_circle(Vector2(0, 34), 4.0, BRICK_DARK)


func _draw_itchan_kala() -> void:
	draw_rect(Rect2(-22, -96, 44, 192), BRICK_DARK)
	draw_rect(Rect2(-18, -96, 36, 192), BRICK)
	for step in range(12):
		draw_rect(Rect2(-24, -94 + step * 16, 8, 9), BRICK_DARK)
		draw_rect(Rect2(16, -94 + step * 16, 8, 9), BRICK_DARK)
	var centre := Vector2(0, 8)
	draw_circle(centre + Vector2(5, 6), 40.0, SHADOW)
	var rings: Array[Color] = [TURQUOISE_DARK, CREAM, TURQUOISE, TILE_BLUE, CREAM, TURQUOISE]
	for index in range(rings.size()):
		draw_circle(centre, 38.0 - index * 5.5, rings[index])
	draw_arc(centre, 38.0, 0.0, TAU, 32, BRICK_DARK, 2.0)
	draw_circle(centre, 6.0, BRICK)


func _draw_dome(centre: Vector2, radius: float) -> void:
	draw_circle(centre + Vector2(4, 5), radius, SHADOW)
	draw_circle(centre, radius, TURQUOISE_DARK)
	draw_circle(centre, radius - 3.0, TURQUOISE)
	for step in range(10):
		var unit := Vector2.from_angle(TAU * step / 10.0)
		draw_line(centre + unit * 5.0, centre + unit * (radius - 3.0), TURQUOISE_DARK, 1.5)
	draw_circle(centre + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1, 1, 1, 0.25))
	draw_circle(centre, 4.0, CREAM)


func _draw_minaret(base: Vector2, radius: float) -> void:
	draw_circle(base + Vector2(3, 3), radius, SHADOW)
	draw_circle(base, radius, BRICK)
	draw_arc(base, radius - 3.0, 0.0, TAU, 16, TILE_BLUE, 2.5)
	draw_circle(base, radius * 0.4, CREAM)


func _draw_arch(box: Rect2, colour: Color) -> void:
	var top := box.position.y
	var points := PackedVector2Array(
		[
			Vector2(box.position.x, box.end.y),
			Vector2(box.position.x, top + box.size.x * 0.5),
			Vector2(box.get_center().x, top),
			Vector2(box.end.x, top + box.size.x * 0.5),
			Vector2(box.end.x, box.end.y),
		]
	)
	draw_colored_polygon(points, colour)

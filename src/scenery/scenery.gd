class_name SceneryView
extends Node2D
## Connected painted street, aligned to the same bounds used by driving and traffic.

const REPEAT_DISTANCE: float = 720.0
const STREET: Texture2D = preload("res://assets/scenery/mahalla_street.png")
# Crop at the repeated courtyard wall. The lower garden duplicates the upper one.
const SOURCE_HEIGHT: float = 1540.0
const SOURCE_LEFT: float = 270.0
const SOURCE_RIGHT: float = 674.0

var scroll_offset: float = 0.0
var _settings: RoadSettings
var _view_bounds := Rect2(0, 0, 432, 768)


func configure(settings: RoadSettings) -> void:
	_settings = settings
	scroll_offset = 0.0
	queue_redraw()


func advance(travel_pixels: float) -> void:
	scroll_offset = fposmod(scroll_offset + travel_pixels, REPEAT_DISTANCE)
	queue_redraw()


func set_view_bounds(bounds: Rect2) -> void:
	_view_bounds = bounds
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var first := floori((_view_bounds.position.y - scroll_offset) / REPEAT_DISTANCE)
	var last := ceili((_view_bounds.end.y - scroll_offset) / REPEAT_DISTANCE)
	for index in range(first, last):
		var y := index * REPEAT_DISTANCE + scroll_offset
		# Map each curb to the route resource; alternate road widths stay aligned.
		_draw_strip(y, _view_bounds.position.x, _settings.left_edge, 0.0, SOURCE_LEFT)
		_draw_strip(y, _settings.left_edge, _settings.right_edge, SOURCE_LEFT, SOURCE_RIGHT)
		_draw_strip(y, _settings.right_edge, _view_bounds.end.x, SOURCE_RIGHT, STREET.get_width())
		_draw_bakery_sign(y)


func _draw_bakery_sign(y: float) -> void:
	var width := _settings.left_edge * 0.34
	draw_rect(Rect2(6, y + 129, width, 13), Color("e8d3a4"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(6, y + 139),
		"NON",
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		10,
		Color("71422b")
	)


func _draw_strip(
	y: float, left: float, right: float, source_left: float, source_right: float
) -> void:
	draw_texture_rect_region(
		STREET,
		Rect2(left, y, right - left, REPEAT_DISTANCE),
		Rect2(source_left, 0.0, source_right - source_left, SOURCE_HEIGHT)
	)

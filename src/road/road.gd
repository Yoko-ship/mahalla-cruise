class_name RoadView
extends Node2D
## Moving lane markings above the painted street surface.

const DASH_PERIOD: float = 100.0

var scroll_offset: float = 0.0
var _settings: RoadSettings
var _view_bounds := Rect2(0, 0, 432, 768)


func configure(settings: RoadSettings) -> void:
	_settings = settings
	scroll_offset = 0.0
	queue_redraw()


func advance(travel_pixels: float) -> void:
	scroll_offset = fposmod(scroll_offset + travel_pixels, DASH_PERIOD)
	queue_redraw()


func set_view_bounds(bounds: Rect2) -> void:
	_view_bounds = bounds
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var centre_x := (_settings.left_edge + _settings.right_edge) / 2.0
	var first := floori((_view_bounds.position.y - scroll_offset) / DASH_PERIOD)
	var last := ceili((_view_bounds.end.y - scroll_offset) / DASH_PERIOD)
	for index in range(first, last):
		var y := index * DASH_PERIOD + scroll_offset
		draw_rect(Rect2(centre_x - 1.5, y, 3, 35), Color("d2c5ab", 0.7))

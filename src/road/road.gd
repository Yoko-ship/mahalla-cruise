class_name RoadView
extends Node2D
## Moving lane markings above the painted street surface.

const DASH_PERIOD: float = 100.0

var scroll_offset: float = 0.0
var _settings: RoadSettings


func configure(settings: RoadSettings) -> void:
	_settings = settings
	scroll_offset = 0.0
	queue_redraw()


func advance(travel_pixels: float) -> void:
	scroll_offset = fposmod(scroll_offset + travel_pixels, DASH_PERIOD)
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var centre_x := (_settings.left_edge + _settings.right_edge) / 2.0
	for index in range(-1, 9):
		var y := index * DASH_PERIOD + scroll_offset
		draw_rect(Rect2(centre_x - 1.5, y, 3, 35), Color("d2c5ab", 0.7))

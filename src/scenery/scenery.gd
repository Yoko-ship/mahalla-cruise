class_name SceneryView
extends Node2D
## Connected streets aligned to driving bounds. A district enters from the top,
## with a short feathered join; cars and lane markings remain above both artworks.

const DEFAULT_ART: StreetArt = preload("res://src/scenery/mahalla_art.tres")
const JOIN_PIXELS: float = 32.0
const JOIN_STEPS: int = 8

var art: StreetArt = DEFAULT_ART
var scroll_offset: float = 0.0
var previous_art: StreetArt
var transition: float = 1.0
var _travel: float = 0.0
var _settings: RoadSettings
var _view_bounds := Rect2(0, 0, 432, 768)


func configure(settings: RoadSettings) -> void:
	_settings = settings
	set_street_art(art)


func set_street_art(value: StreetArt) -> void:
	art = value if value != null else DEFAULT_ART
	scroll_offset = 0.0
	_travel = 0.0
	previous_art = null
	transition = 1.0
	queue_redraw()


func set_location(value: StreetArt, previous: StreetArt, progress: float) -> void:
	art = value if value != null else DEFAULT_ART
	previous_art = previous
	transition = clampf(progress, 0.0, 1.0)
	scroll_offset = fposmod(_travel, art.repeat_distance)
	queue_redraw()


func advance(travel_pixels: float) -> void:
	_travel += travel_pixels
	scroll_offset = fposmod(_travel, art.repeat_distance)
	queue_redraw()


func set_view_bounds(bounds: Rect2) -> void:
	_view_bounds = bounds
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var clip := Vector2(_view_bounds.position.y, _view_bounds.end.y)
	if previous_art == null or transition >= 1.0:
		_draw_art(art, scroll_offset, clip)
		return
	_draw_art(previous_art, fposmod(_travel, previous_art.repeat_distance), clip)
	var front := lerpf(clip.x - JOIN_PIXELS, clip.y + JOIN_PIXELS, transition)
	_draw_art(art, scroll_offset, Vector2(clip.x, minf(front, clip.y)))
	for step in JOIN_STEPS:
		var top := front + JOIN_PIXELS * step / JOIN_STEPS
		var bottom := top + JOIN_PIXELS / JOIN_STEPS
		var band := Vector2(maxf(clip.x, top), minf(clip.y, bottom))
		_draw_art(art, scroll_offset, band, Color(1, 1, 1, 1.0 - float(step + 1) / JOIN_STEPS))


func _draw_art(value: StreetArt, offset: float, clip: Vector2, tint := Color.WHITE) -> void:
	if clip.y <= clip.x:
		return
	var repeat := value.repeat_distance
	var first := floori((clip.x - offset) / repeat)
	var last := ceili((clip.y - offset) / repeat)
	var left := Vector2(_view_bounds.position.x, _settings.left_edge)
	var road := Vector2(_settings.left_edge, _settings.right_edge)
	var right := Vector2(_settings.right_edge, _view_bounds.end.x)
	for index in range(first, last):
		var y := index * repeat + offset
		_draw_strip(value, y, left, Vector2(0, value.source_curbs.x), clip, tint)
		_draw_strip(value, y, road, value.source_curbs, clip, tint)
		_draw_strip(
			value, y, right, Vector2(value.source_curbs.y, value.texture.get_width()), clip, tint
		)
		if value.bakery_sign and y + 129 >= clip.x and y + 142 <= clip.y:
			_draw_bakery_sign(y, tint)


func _draw_bakery_sign(y: float, tint: Color) -> void:
	var width := _settings.left_edge * 0.34
	draw_rect(Rect2(6, y + 129, width, 13), Color("e8d3a4") * tint)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(6, y + 139),
		"NON",
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		10,
		Color("71422b") * tint
	)


func _draw_strip(
	value: StreetArt, y: float, edges: Vector2, source: Vector2, clip: Vector2, tint: Color
) -> void:
	var top := maxf(y, clip.x)
	var bottom := minf(y + value.repeat_distance, clip.y)
	if bottom <= top:
		return
	var height: float = (
		value.source_height if value.source_height > 0 else float(value.texture.get_height())
	)
	var scale := height / value.repeat_distance
	draw_texture_rect_region(
		value.texture,
		Rect2(edges.x, top, edges.y - edges.x, bottom - top),
		Rect2(source.x, (top - y) * scale, source.y - source.x, (bottom - top) * scale),
		tint
	)

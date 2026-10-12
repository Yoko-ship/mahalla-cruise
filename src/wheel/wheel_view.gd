class_name WheelView
extends Control
## Draws the lucky wheel: coloured segments with point values or power-up icons, a gold rim
## with studs, and the pointer at the top. The menu sets `angle` while it spins.

const RIM := Color(1, 0.85, 0.47, 1)
const RIM_DARK := Color(0.55, 0.42, 0.16, 1)
const TEXT := Color(1, 0.98, 0.92, 1)
const HUB := Color(0.12549, 0.243137, 0.219608, 1)

## Rotation of the whole wheel in radians; segment 0 starts at the top when it is 0.
var angle: float = 0.0
var _settings: WheelSettings


func set_settings(settings: WheelSettings) -> void:
	_settings = settings
	queue_redraw()


## The angle that puts the middle of segment index under the pointer.
func angle_for(index: int) -> float:
	return -(index + 0.5) * TAU / maxi(1, _settings.size())


func _draw() -> void:
	if _settings == null or _settings.size() == 0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 10.0
	var step := TAU / _settings.size()
	draw_circle(center + Vector2(0, 5), radius + 8.0, Color(0, 0, 0, 0.25))
	draw_circle(center, radius + 8.0, RIM_DARK)
	draw_circle(center, radius + 5.0, RIM)
	for index in range(_settings.size()):
		var from := -PI * 0.5 + angle + index * step
		var points := PackedVector2Array([center])
		for corner in range(13):
			points.append(center + Vector2.from_angle(from + step * corner / 12.0) * radius)
		draw_colored_polygon(points, _settings.colors[index % _settings.colors.size()])
		var middle := from + step * 0.5
		var spot := center + Vector2.from_angle(middle) * radius * 0.66
		if _settings.kinds[index] == "points":
			_draw_value(spot, middle, str(_settings.amounts[index]))
		else:
			PowerUpVisual.draw_icon(self, _settings.kinds[index], spot, radius * 0.13)
	for stud in range(_settings.size() * 2):
		var spot := (
			center + Vector2.from_angle(-PI * 0.5 + angle + stud * step * 0.5) * (radius + 2.5)
		)
		draw_circle(spot, 2.6, Color.WHITE if stud % 2 == 0 else RIM_DARK)
	draw_circle(center, radius * 0.17, RIM)
	draw_circle(center, radius * 0.13, HUB)
	var tip := center - Vector2(0, radius - 14.0)
	var pointer := PackedVector2Array(
		[tip, center - Vector2(13, radius + 14.0), center - Vector2(-13, radius + 14.0)]
	)
	draw_colored_polygon(pointer, Color("e8364f"))
	draw_polyline(pointer + PackedVector2Array([tip]), Color.WHITE, 2.0)


func _draw_value(spot: Vector2, direction: float, text: String) -> void:
	var font := get_theme_default_font()
	# Values on the lower half turn the other way, so none reads upside down.
	var turn := fposmod(direction + PI * 0.5, TAU)
	if turn > PI * 0.5 and turn < PI * 1.5:
		turn += PI
	draw_set_transform(spot, turn)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(
		font,
		Vector2(-width * 0.5 + 1, 7),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color(0, 0, 0, 0.3)
	)
	draw_string(font, Vector2(-width * 0.5, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
	draw_set_transform(Vector2.ZERO)

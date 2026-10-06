class_name MoneyVisual
extends Node2D
## Scaled banknote artwork and a readable value badge, with a soft ground shadow.

var denomination: BanknoteDefinition
var phase: float = 0.0


func _draw() -> void:
	if denomination == null or denomination.texture == null:
		return
	var texture := denomination.texture
	var height := 44.0 * texture.get_height() / texture.get_width()
	var tint := Color("a2d7b2") if denomination.is_dollar else Color("edc66e")
	draw_circle(Vector2.ZERO, 25, Color(tint, 0.09))
	draw_rect(Rect2(-19, -height * 0.5 + 4, 44, height), Color(0.1, 0.12, 0.1, 0.24))
	draw_set_transform(Vector2(0, sin(phase) * 1.5), -0.04)
	draw_texture_rect(texture, Rect2(-22, -height * 0.5, 44, height), false)
	draw_set_transform(Vector2.ZERO)
	var label := denomination.display_name().trim_suffix(" soʻm")
	var label_position := Vector2(-30, height * 0.5 + 12)
	draw_string_outline(
		ThemeDB.fallback_font,
		label_position,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		11,
		4,
		Color("263c32")
	)
	draw_string(
		ThemeDB.fallback_font,
		label_position,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		11,
		Color("fff4d4")
	)

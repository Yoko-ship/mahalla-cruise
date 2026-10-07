class_name PowerUpVisual
extends Node2D
## Drawn power-up badge: magnet, ×2, or shield. The HUD reuses draw_icon() for its chips.

const COLORS := {"magnet": Color("d8453c"), "double": Color("e2ae36"), "shield": Color("3e82d2")}
const INK := Color("fff8e6")

var kind: String = "magnet"
var phase: float = 0.0


static func draw_icon(canvas: CanvasItem, icon: String, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius + 2.0, Color("263c32"))
	canvas.draw_circle(center, radius, COLORS.get(icon, Color.WHITE))
	var unit := radius / 15.0
	match icon:
		"magnet":
			canvas.draw_arc(center + Vector2(0, 2) * unit, 7 * unit, 0.0, PI, 16, INK, 4.5 * unit)
			for side: float in [-1.0, 1.0]:
				var tip := center + Vector2(side * 7, -4) * unit
				canvas.draw_line(tip, tip + Vector2(0, 6) * unit, INK, 4.5 * unit)
		"shield":
			var points := PackedVector2Array(
				[Vector2(-7, -8), Vector2(7, -8), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)]
			)
			for index in range(points.size()):
				points[index] = center + points[index] * unit
			canvas.draw_colored_polygon(points, INK)
		_:
			var font := ThemeDB.fallback_font
			var size := int(13 * unit)
			var text_size := font.get_string_size("×2", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			var origin := center + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
			canvas.draw_string(font, origin, "×2", HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)


func _draw() -> void:
	draw_circle(Vector2(3, 5), 17.0, Color(0.1, 0.12, 0.1, 0.22))
	draw_circle(Vector2.ZERO, 22.0 + sin(phase) * 2.0, Color(COLORS.get(kind, INK), 0.18))
	draw_icon(self, kind, Vector2(0, sin(phase) * 1.5), 15.0)

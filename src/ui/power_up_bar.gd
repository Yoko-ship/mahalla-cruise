class_name PowerUpBar
extends Control
## Active power-up chips: the icon with a ring showing how much time is left.

const RADIUS: float = 13.0
const SPACING: float = 40.0
const RING := Color(1, 0.96, 0.85, 1)
const TRACK := Color(0.07, 0.15, 0.13, 0.7)

var _view: Dictionary = {}


func set_view(view: Dictionary) -> void:
	_view = view.duplicate()
	queue_redraw()


func active_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for kind in PowerUpSettings.KINDS:
		var value: Variant = _view.get(kind, 0.0)
		if (value is bool and value) or (value is float and value > 0.0):
			kinds.append(kind)
	return kinds


func _draw() -> void:
	var center := Vector2(RADIUS + 5.0, RADIUS + 5.0)
	for kind in active_kinds():
		var value: Variant = _view[kind]
		var share: float = 1.0 if value is bool else float(value)
		draw_arc(center, RADIUS + 4.0, 0.0, TAU, 32, TRACK, 3.0)
		draw_arc(center, RADIUS + 4.0, -PI * 0.5, -PI * 0.5 + TAU * share, 32, RING, 3.0)
		PowerUpVisual.draw_icon(self, kind, center, RADIUS)
		center.x += SPACING

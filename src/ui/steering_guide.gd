class_name SteeringGuide
extends Control
## A finger moving between arrows demonstrates steering without requiring reading.

const CREAM := Color("fff5d9")
const GOLD := Color("e0cf91")
const GREEN := Color("203e38")

var _time: float = 0.0


func advance(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var finger := center + Vector2(sin(_time * 2.0) * 24.0, 0)
	draw_line(center - Vector2(58, 0), center + Vector2(58, 0), GREEN, 6, true)
	for direction: float in [-1.0, 1.0]:
		var tip := center + Vector2(direction * 64.0, 0)
		draw_polyline(
			PackedVector2Array(
				[tip + Vector2(-direction * 10, -9), tip, tip + Vector2(-direction * 10, 9)]
			),
			GOLD,
			4,
			true
		)
	draw_circle(finger, 13.0, GREEN)
	draw_circle(finger, 8.0, CREAM)
	draw_line(finger, finger + Vector2(0, 22), CREAM, 10, true)
	draw_circle(finger + Vector2(0, 22), 5.0, CREAM)

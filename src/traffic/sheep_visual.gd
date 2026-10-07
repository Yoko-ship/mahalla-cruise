class_name SheepVisual
extends Node2D
## Simple drawn sheep seen from above: woolly body, dark head, stepping legs, soft shadow.
## Temporary art until painted sheep matching the street exist.

const WOOL := Color("f3ecdc")
const WOOL_SHADE := Color("d9cfba")
const FACE := Color("3a332e")

var facing: float = 1.0
var _phase: float = 0.0


func step(pixels: float) -> void:
	_phase = fmod(_phase + pixels * 0.35, TAU)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	var shadow := Color(0.12, 0.14, 0.15, 0.16)
	draw_circle(Vector2(3, 6), 11.0, shadow)
	var swing := sin(_phase) * 2.0
	for leg in [Vector2(-7, swing), Vector2(5, -swing), Vector2(-7, -swing), Vector2(5, swing)]:
		var side := 1.0 if leg.y >= 0.0 else -1.0
		draw_rect(Rect2(leg.x + leg.y, 4.0 * side - 1.5, 3, 3), FACE)
	for puff in [
		Vector2(-6, -2),
		Vector2(0, -4),
		Vector2(5, -2),
		Vector2(-5, 3),
		Vector2(1, 3),
		Vector2(5, 2)
	]:
		draw_circle(puff + Vector2(0.6, 0.8), 5.2, WOOL_SHADE)
	for puff in [Vector2(-6, -2), Vector2(0, -4), Vector2(5, -2), Vector2(-5, 3), Vector2(1, 3)]:
		draw_circle(puff, 4.6, WOOL)
	draw_circle(Vector2(12, 0), 4.0, FACE)
	draw_circle(Vector2(10, -4), 1.6, FACE)
	draw_circle(Vector2(10, 4), 1.6, FACE)

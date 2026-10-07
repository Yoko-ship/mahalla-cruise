class_name TrafficCar
extends Node2D
## Per-vehicle position and contact state; the traffic controller supplies movement.

var has_contacted: bool = false
var has_passed: bool = false
## Smallest side gap to the player while level with it; INF until they overlap vertically.
var closest_gap: float = INF
var _half_size := Vector2(20, 36)

@onready var visual: TrafficVisual = $Visual


func configure(half_size: Vector2, paint: Color) -> void:
	_half_size = half_size
	visual.paint = paint
	visual.queue_redraw()


func advance(pixels: float) -> void:
	position.y += pixels


func collision_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)


func mark_contacted() -> void:
	has_contacted = true
	visual.modulate = Color("efa69a")

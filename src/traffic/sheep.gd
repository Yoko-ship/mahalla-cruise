class_name Sheep
extends Node2D
## One crossing sheep: position, walking direction, and contact state. Drawn by its visual.

var direction: float = 1.0
var has_contacted: bool = false
var _half_size := Vector2(11, 8)
var _stop_x: float = 0.0

@onready var visual: SheepVisual = $Visual


func configure(half_size: Vector2, walk_direction: float, stop_x: float) -> void:
	_half_size = half_size
	direction = walk_direction
	_stop_x = stop_x
	visual.facing = walk_direction
	visual.queue_redraw()


func advance(travel_pixels: float, walk_pixels: float) -> void:
	position.y += travel_pixels
	# Sheep stop on the far sidewalk instead of walking into the courtyard walls.
	var walked := (_stop_x - position.x) * direction
	var step := minf(walk_pixels, maxf(0.0, walked))
	position.x += step * direction
	if step > 0.0:
		visual.step(step)


func collision_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)


func mark_contacted() -> void:
	has_contacted = true
	visual.modulate = Color("efa69a")

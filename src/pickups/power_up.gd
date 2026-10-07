class_name PowerUp
extends Node2D
## One power-up on the road. The pickup controller owns its lifetime and effect.

var kind: String = "magnet"
var _half_size := Vector2(16, 16)

@onready var visual: PowerUpVisual = $Visual


func configure(power_kind: String, half_size: Vector2) -> void:
	kind = power_kind
	_half_size = half_size
	visual.kind = power_kind
	visual.queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels
	visual.phase = fposmod(visual.phase + travel_pixels / 40.0, TAU)
	visual.queue_redraw()


func collection_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)

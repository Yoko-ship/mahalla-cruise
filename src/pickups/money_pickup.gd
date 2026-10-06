class_name MoneyPickup
extends Node2D
## One collectible's value and bounds. The controller owns its lifetime.

var is_dollar: bool = false
var denomination: BanknoteDefinition
var points: int = 0
var _half_size := Vector2(17, 12)

@onready var visual: MoneyVisual = $Visual


func configure(note: BanknoteDefinition, value: int, half_size: Vector2) -> void:
	denomination = note
	is_dollar = note.is_dollar
	points = value
	_half_size = half_size
	visual.denomination = note
	visual.queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels
	visual.phase = fposmod(visual.phase + travel_pixels / 45.0, TAU)
	visual.queue_redraw()


func collection_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)

class_name RoadHazard
extends Node2D
## A pothole or a road-works barrier. Drawn in code (temporary art). The controller moves it
## with the road and decides when it is hit.

const RIM := Color("4a4842")
const HOLE := Color("1d1c1a")
const CRACK := Color("2e2d29")
const STRIPE_RED := Color("d23a2c")
const STRIPE_WHITE := Color("f2efe6")
const CONE := Color("f07b1d")
const SHADOW := Color(0.08, 0.09, 0.07, 0.25)

var kind: String = "pothole"
var is_hit: bool = false
var _half_size := Vector2(15, 9)


func configure(hazard_kind: String, half_size: Vector2) -> void:
	kind = hazard_kind
	_half_size = half_size
	queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels


func collision_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)


func mark_hit() -> void:
	is_hit = true
	# A knocked barrier fades; a pothole stays as it is.
	if kind == "works":
		modulate.a = 0.5
		rotation = 0.12
	queue_redraw()


func _draw() -> void:
	if kind == "works":
		_draw_works()
	else:
		_draw_pothole()


func _draw_pothole() -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for step in range(14):
		var angle := TAU * step / 14.0
		# Fixed bumps keep the edge ragged without randomness.
		var wobble := 1.0 + 0.12 * sin(angle * 3.0) + 0.06 * cos(angle * 5.0)
		var unit := Vector2(cos(angle) * _half_size.x, sin(angle) * _half_size.y)
		outer.append(unit * wobble * 1.15)
		inner.append(unit * wobble * 0.82)
	draw_colored_polygon(outer, RIM)
	draw_colored_polygon(inner, HOLE)
	draw_line(Vector2(_half_size.x * 0.9, -2), Vector2(_half_size.x * 1.5, -6), CRACK, 1.5)
	draw_line(Vector2(-_half_size.x * 0.9, 3), Vector2(-_half_size.x * 1.4, 7), CRACK, 1.5)


func _draw_works() -> void:
	var width := _half_size.x * 2.0
	var bar := Rect2(-_half_size.x, -5, width, 10)
	draw_rect(Rect2(bar.position + Vector2(2, 4), bar.size), SHADOW)
	draw_rect(bar, STRIPE_WHITE)
	var stripes := 5
	for index in range(stripes):
		if index % 2 == 0:
			var stripe_x := -_half_size.x + width * index / stripes
			draw_rect(Rect2(stripe_x, -5, width / stripes, 10), STRIPE_RED)
	for side: float in [-1.0, 1.0]:
		var base := Vector2(side * (_half_size.x - 2.0), 9)
		draw_colored_polygon(
			PackedVector2Array(
				[base + Vector2(-5, 3), base + Vector2(5, 3), base + Vector2(0, -12)]
			),
			CONE
		)
		draw_rect(Rect2(base + Vector2(-3, -5), Vector2(6, 2)), STRIPE_WHITE)

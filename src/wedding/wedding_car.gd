class_name WeddingCar
extends Node2D
## One white convoy car with wedding ribbons and a flower garland; the lead car also carries
## balloons. Music notes rise while the convoy plays. Drawn over the shared sedan sprite
## (code-drawn decorations are temporary art). The controller supplies movement.

## Brighter than the sprite itself, so the convoy reads as freshly washed white cars.
const WHITE := Color(1.3, 1.3, 1.28)
const RIBBON := Color("e2476b")
const RIBBON_DARK := Color("b3264d")
const FLOWERS: Array[Color] = [Color("ffd4e0"), Color("ffffff"), Color("f7c948"), Color("e2476b")]
const BALLOONS: Array[Color] = [Color("e8364f"), Color("ffffff"), Color("f59ab5"), Color("f2c230")]
const NOTE := Color(1, 0.95, 0.75, 0.9)

var is_lead: bool = false
var playing: bool = false
var _half_size := Vector2(20, 36)
var _phase: float = 0.0


func configure(half_size: Vector2, lead: bool) -> void:
	_half_size = half_size
	is_lead = lead
	queue_redraw()


func move(pixels: float) -> void:
	position.y += pixels


## Balloons bob and notes rise with road travel, so pause freezes them.
func animate(travel_pixels: float) -> void:
	_phase = fposmod(_phase + travel_pixels / 60.0, TAU * 4.0)
	queue_redraw()


func collision_bounds() -> Rect2:
	return Rect2(position - _half_size, _half_size * 2.0)


func _draw() -> void:
	for layer in range(4):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.12, 0.14, 0.15, 0.045)
		shadow.set_corner_radius_all(11)
		var spread := float(layer) * 2.0
		draw_style_box(shadow, Rect2(-13 - spread, -13 - spread, 42 + spread * 2, 56 + spread * 2))
	draw_texture_rect_region(
		TrafficVisual.VEHICLES, Rect2(-25, -36, 50, 72), TrafficVisual.SEDAN_REGION, WHITE
	)
	_draw_ribbons()
	_draw_garland()
	if is_lead:
		_draw_balloons()
	if playing:
		_draw_notes()


func _draw_ribbons() -> void:
	# Two ribbons cross the roof from corner to corner, tied in a bow in the middle.
	draw_line(Vector2(-14, -29), Vector2(14, -8), RIBBON, 1.6)
	draw_line(Vector2(14, -29), Vector2(-14, -8), RIBBON, 1.6)
	var knot := Vector2(0, -18.5)
	draw_colored_polygon(
		PackedVector2Array([knot, knot + Vector2(-7, -4), knot + Vector2(-7, 4)]), RIBBON
	)
	draw_colored_polygon(
		PackedVector2Array([knot, knot + Vector2(7, -4), knot + Vector2(7, 4)]), RIBBON
	)
	draw_circle(knot, 2.0, RIBBON_DARK)


func _draw_garland() -> void:
	for index in range(7):
		var x := -18.0 + index * 6.0
		var sag := 3.0 * sin(PI * index / 6.0)
		draw_circle(Vector2(x, 14 + sag), 2.6, FLOWERS[index % FLOWERS.size()])


func _draw_balloons() -> void:
	var anchors := [Vector2(-21, -30), Vector2(21, -30)]
	var offsets := [Vector2(-10, -24), Vector2(-2, -32), Vector2(6, -22), Vector2(12, -30)]
	for side in range(2):
		for index in range(2):
			var colour_index := side * 2 + index
			var bob := Vector2(0, 2.5 * sin(_phase + colour_index * 1.3))
			var offset: Vector2 = offsets[colour_index]
			var balloon: Vector2 = anchors[side] + Vector2(offset.x * 0.6, offset.y) + bob
			draw_line(anchors[side], balloon + Vector2(0, 7), Color(1, 1, 1, 0.7), 1.0)
			draw_circle(balloon + Vector2(1.5, 2), 7.0, Color(0, 0, 0, 0.12))
			draw_circle(balloon, 7.0, BALLOONS[colour_index])
			draw_circle(balloon + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.55))


func _draw_notes() -> void:
	# Two notes rise from the roof and fade, offset from each other.
	for index in range(2):
		var rise := fposmod(_phase * 0.5 + index * 0.5, 1.0)
		var spot := Vector2(-10 + index * 20 + 4 * sin(_phase + index), -40 - rise * 30)
		var colour := Color(NOTE, NOTE.a * (1.0 - rise))
		draw_circle(spot, 3.0, colour)
		draw_line(spot + Vector2(2.6, 0), spot + Vector2(2.6, -11), colour, 1.6)
		draw_line(spot + Vector2(2.6, -11), spot + Vector2(7, -8), colour, 1.6)

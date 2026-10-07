class_name BusStop
extends Node2D
## A marshrutka stop on the right sidewalk with waiting passengers. Drawn in code
## (temporary art): shelter, BEKAT sign, and simple figures.

const ROOF := Color("2f7f78")
const POST := Color("3a3f3c")
const SIGN := Color("f1c74a")
const SKIN := Color("c98f63")
const CLOTHES: Array[Color] = [Color("c3423f"), Color("3f6fb5"), Color("6c9c48"), Color("8a5aa6")]

var passengers: int = 0
var curb_x: float = 0.0
var _zone_height: float = 64.0


func configure(count: int, curb: float, zone_height: float) -> void:
	passengers = count
	curb_x = curb
	_zone_height = zone_height
	queue_redraw()


func advance(travel_pixels: float) -> void:
	position.y += travel_pixels


## The road strip beside the stop, ending at the curb, where a car must be to board.
func boarding_zone(board_distance: float) -> Rect2:
	var top := position.y - _zone_height * 0.5
	return Rect2(curb_x - board_distance, top, board_distance, _zone_height)


func board() -> int:
	var boarded := passengers
	passengers = 0
	queue_redraw()
	return boarded


func _draw() -> void:
	# Drawn 35% larger than its layout units so passengers read at phone size.
	draw_set_transform(Vector2(curb_x - position.x, 0), 0.0, Vector2(1.35, 1.35))
	var base := Vector2.ZERO
	draw_rect(Rect2(base + Vector2(4, -30), Vector2(30, 6)), ROOF)
	draw_rect(Rect2(base + Vector2(30, -26), Vector2(3, 34)), POST)
	draw_rect(Rect2(base + Vector2(6, -26), Vector2(2, 30)), POST)
	draw_rect(Rect2(base + Vector2(1, -48), Vector2(38, 14)), SIGN)
	draw_string(
		ThemeDB.fallback_font,
		base + Vector2(3, -37),
		"BEKAT",
		HORIZONTAL_ALIGNMENT_LEFT,
		36,
		10,
		Color("263c32")
	)
	for index in range(passengers):
		var foot := base + Vector2(12 + index * 8, 16 - (index % 2) * 6)
		draw_circle(foot + Vector2(2, 1), 4.0, Color(0.1, 0.12, 0.1, 0.2))
		draw_rect(Rect2(foot + Vector2(-3, -12), Vector2(6, 11)), CLOTHES[index % CLOTHES.size()])
		draw_circle(foot + Vector2(0, -15), 3.2, SKIN)
		draw_rect(Rect2(foot + Vector2(-3, -19), Vector2(6, 2.5)), Color("263c32"))

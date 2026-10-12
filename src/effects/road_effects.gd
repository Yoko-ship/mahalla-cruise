class_name RoadEffects
extends Node2D
## Short-lived effects over the street (z 5): point popups that rise and fade where they
## were earned, and a dust puff where a crash happened. They run in real time, so they
## finish while menus are open. Drawn in code; the world says what and where.

const POPUP_SECONDS: float = 0.9
const POPUP_RISE: float = 46.0
const PUFF_SECONDS: float = 0.6
const GAIN := Color(1, 0.88, 0.45, 1)
const CLOSE := Color(0.62, 0.9, 1, 1)
const LOSS := Color(1, 0.45, 0.4, 1)
const OUTLINE := Color(0.16, 0.18, 0.14, 0.9)

## Each popup: spot, text, colour, and age in seconds.
var popups: Array[Dictionary] = []
## Each puff: spot and age in seconds.
var puffs: Array[Dictionary] = []


func pop(spot: Vector2, text: String, colour: Color = GAIN) -> void:
	popups.append({"spot": spot, "text": text, "colour": colour, "age": 0.0})
	set_process(true)
	queue_redraw()


func puff(spot: Vector2) -> void:
	puffs.append({"spot": spot, "age": 0.0})
	set_process(true)
	queue_redraw()


func clear() -> void:
	popups.clear()
	puffs.clear()
	set_process(false)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	for popup in popups:
		popup.age += delta
	for dust in puffs:
		dust.age += delta
	popups = popups.filter(func(popup: Dictionary) -> bool: return popup.age < POPUP_SECONDS)
	puffs = puffs.filter(func(dust: Dictionary) -> bool: return dust.age < PUFF_SECONDS)
	set_process(not popups.is_empty() or not puffs.is_empty())
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for dust in puffs:
		var share: float = dust.age / PUFF_SECONDS
		for index in range(8):
			var direction := Vector2.from_angle(TAU * index / 8.0 + 0.4)
			var spot: Vector2 = dust.spot + direction * (8.0 + 30.0 * share)
			draw_circle(spot, 7.0 + 8.0 * share, Color(0.78, 0.74, 0.66, 0.55 * (1.0 - share)))
	for popup in popups:
		var share: float = popup.age / POPUP_SECONDS
		var spot: Vector2 = popup.spot - Vector2(0, POPUP_RISE * (1.0 - pow(1.0 - share, 2.0)))
		var size := 20 if share < 0.12 else 18
		var width := font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var fade := clampf((1.0 - share) * 2.5, 0.0, 1.0)
		var origin := spot - Vector2(width * 0.5, 0)
		draw_string_outline(
			font, origin, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(OUTLINE, fade)
		)
		var colour: Color = popup.colour
		draw_string(
			font, origin, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(colour, fade)
		)

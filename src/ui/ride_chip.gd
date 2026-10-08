class_name RideChip
extends Control
## The taxi passenger's ride: a TAKSI badge and the metres left to the drop-off.

const BACKGROUND := Color(0.21, 0.23, 0.19, 0.9)
const BORDER := Color(0.97, 0.79, 0.2, 0.9)
const BADGE := Color(0.97, 0.79, 0.2, 1)
const INK := Color(0.11, 0.12, 0.11, 1)
const TEXT := Color(1, 0.96, 0.85, 1)
const BADGE_WIDTH: float = 44.0

var metres: int = -1
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.bg_color = BACKGROUND
	_box.border_color = BORDER
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(12)


## -1 hides the chip; 0 asks the driver to pull over.
func set_metres(value: int) -> void:
	if value == metres:
		return
	metres = value
	queue_redraw()


func text() -> String:
	if metres < 0:
		return ""
	return tr("taxi_ride") % metres if metres > 0 else tr("taxi_pull_over")


func refresh_text() -> void:
	queue_redraw()


func _draw() -> void:
	if metres < 0:
		return
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var badge := Rect2(4, 4, BADGE_WIDTH, size.y - 8)
	draw_rect(badge, BADGE)
	var font := get_theme_default_font()
	var baseline := size.y * 0.5 + 4.0
	draw_string(
		font, Vector2(4, baseline), "TAKSI", HORIZONTAL_ALIGNMENT_CENTER, BADGE_WIDTH, 11, INK
	)
	var left := BADGE_WIDTH + 10.0
	draw_string(
		font,
		Vector2(left, baseline),
		text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - left - 6.0,
		13,
		TEXT
	)

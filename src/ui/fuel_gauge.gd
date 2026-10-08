class_name FuelGauge
extends Control
## Methane gauge: a label and a bar that turns red when the tank is low.

const BACKGROUND := Color(0.21, 0.23, 0.19, 0.9)
const BORDER := Color(0.88, 0.84, 0.7, 0.7)
const TRACK := Color(0.07, 0.15, 0.13, 0.8)
const FULL := Color(0.56, 0.84, 0.45, 1)
const LOW := Color(0.95, 0.36, 0.26, 1)
const TEXT := Color(1, 0.96, 0.85, 1)
const LABEL_WIDTH: float = 58.0

var share: float = 1.0
var low: bool = false
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.bg_color = BACKGROUND
	_box.border_color = BORDER
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(13)


func set_level(value: float, is_low: bool) -> void:
	value = clampf(value, 0.0, 1.0)
	# Redraw only for visible changes; the level is reported every frame.
	if absf(value - share) < 0.004 and is_low == low:
		return
	share = value
	low = is_low
	queue_redraw()


func refresh_text() -> void:
	queue_redraw()


func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var baseline := size.y * 0.5 + 5.0
	draw_string(
		font,
		Vector2(10, baseline),
		tr("fuel"),
		HORIZONTAL_ALIGNMENT_LEFT,
		LABEL_WIDTH - 12,
		13,
		TEXT
	)
	var bar := Rect2(LABEL_WIDTH, size.y * 0.5 - 4.0, size.x - LABEL_WIDTH - 12.0, 8.0)
	draw_rect(bar, TRACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), LOW if low else FULL)

class_name PlateView
extends Control
## Draws an Uzbek number plate centred in this control: region code, separator, letters
## and digits, and the flag with "UZ". Display only.

const PLATE_ASPECT: float = 4.6
const BODY := Color(0.98, 0.98, 0.96, 1)
const INK := Color(0.08, 0.08, 0.1, 1)
const FLAG: Array[Color] = [Color("1eb3e6"), Color.WHITE, Color("1eb53a")]
const FLAG_LINE := Color("ce1126")

var code: String = ProgressData.DEFAULT_PLATE:
	set(value):
		code = value
		queue_redraw()


func plate_rect() -> Rect2:
	var height := minf(size.y, size.x / PLATE_ASPECT)
	var width := height * PLATE_ASPECT
	return Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))


func _draw() -> void:
	if not ProgressData.is_plate(code):
		return
	var plate := plate_rect()
	var unit := plate.size.y
	if unit < 8.0:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = BODY
	box.border_color = INK
	box.set_border_width_all(maxi(1, roundi(unit * 0.06)))
	box.set_corner_radius_all(roundi(unit * 0.12))
	draw_style_box(box, plate)
	var font := get_theme_default_font()
	var font_size := roundi(unit * 0.62)
	var baseline := plate.position.y + unit * 0.74
	var region_width := unit * 0.95
	draw_string(
		font,
		Vector2(plate.position.x, baseline),
		code.substr(0, 2),
		HORIZONTAL_ALIGNMENT_CENTER,
		region_width,
		font_size,
		INK
	)
	var divider := plate.position.x + region_width
	draw_line(
		Vector2(divider, plate.position.y + unit * 0.12),
		Vector2(divider, plate.end.y - unit * 0.12),
		INK,
		maxf(1.0, unit * 0.05)
	)
	var flag_width := unit * 0.62
	var text := "%s %s %s" % [code[2], code.substr(3, 3), code.substr(6, 2)]
	var text_width := plate.size.x - region_width - flag_width - unit * 0.3
	draw_string(
		font,
		Vector2(divider + unit * 0.1, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		INK
	)
	var flag := Rect2(
		plate.end.x - flag_width - unit * 0.12,
		plate.position.y + unit * 0.16,
		flag_width,
		unit * 0.4
	)
	for index in range(3):
		var stripe := Rect2(flag.position + Vector2(0, flag.size.y * index / 3.0), flag.size)
		stripe.size.y /= 3.0
		draw_rect(stripe, FLAG[index])
	for index in range(1, 3):
		var y := flag.position.y + flag.size.y * index / 3.0
		draw_line(Vector2(flag.position.x, y), Vector2(flag.end.x, y), FLAG_LINE, 1.0)
	draw_string(
		font,
		Vector2(flag.position.x, plate.end.y - unit * 0.1),
		"UZ",
		HORIZONTAL_ALIGNMENT_CENTER,
		flag.size.x,
		roundi(unit * 0.28),
		INK
	)

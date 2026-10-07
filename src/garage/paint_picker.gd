class_name PaintPicker
extends HBoxContainer
## Color swatches for the selected car. Owned colors apply; others show a price and buy.

signal paint_chosen(id: String)

const BORDER := Color(1, 0.94, 0.75, 1)
const PRICE_DARK := Color(0.1, 0.1, 0.1, 1)
const PRICE_LIGHT := Color(1, 0.97, 0.9, 1)

var swatches: Dictionary = {}


func setup(paints: Array[PaintDefinition]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	swatches.clear()
	for paint in paints:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(44, 48)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_theme_font_size_override("font_size", 11)
		var id := paint.id
		swatch.pressed.connect(func() -> void: paint_chosen.emit(id))
		swatch.set_meta("paint", paint)
		add_child(swatch)
		swatches[id] = swatch


func refresh(selected: String, owned: Array, wallet: int) -> void:
	for id: String in swatches:
		var swatch: Button = swatches[id]
		var paint: PaintDefinition = swatch.get_meta("paint")
		var is_owned := id in owned
		swatch.text = "" if is_owned else str(paint.price)
		swatch.disabled = not is_owned and paint.price > wallet
		var text_color := PRICE_DARK if paint.color.get_luminance() > 0.5 else PRICE_LIGHT
		for state in ["font_color", "font_disabled_color", "font_hover_color", "font_focus_color"]:
			swatch.add_theme_color_override(state, text_color)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			swatch.add_theme_stylebox_override(state, _style(paint.color, id == selected, state))


func _style(color: Color, selected: bool, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color if state != "disabled" else color.darkened(0.45)
	style.set_corner_radius_all(10)
	if state == "focus":
		style.bg_color = Color(0, 0, 0, 0)
	var border := 3 if selected else (2 if state in ["hover", "focus"] else 0)
	style.set_border_width_all(border)
	style.border_color = BORDER
	return style

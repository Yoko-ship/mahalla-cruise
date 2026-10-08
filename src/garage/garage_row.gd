class_name GarageRow
extends PanelContainer
## One car in the garage: preview, stat bars, and a buy or select action.

signal chosen

const STAT_KEYS: Array[String] = ["speed", "control", "size"]
const TEXT_COLOR := Color(1, 0.96, 0.85, 1)
const MUTED_COLOR := Color(0.78, 0.86, 0.81, 1)

var car: CarDefinition
var action: Button
var title: Label
var _stat_labels: Array[Label] = []
var _preview: TextureRect


func setup(definition: CarDefinition) -> void:
	car = definition
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var preview := TextureRect.new()
	_preview = preview
	preview.material = ShaderMaterial.new()
	preview.material.shader = CarVisual.PAINT_SHADER
	preview.texture = car.texture
	preview.custom_minimum_size = Vector2(40, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	layout.add_child(info)
	title = _label(car.display_name, 16, TEXT_COLOR)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(title)
	var ratings: Array[float] = [car.speed_rating(), car.control_rating(), car.size_rating()]
	for rating in ratings:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		info.add_child(line)
		var label := _label("", 11, MUTED_COLOR)
		label.custom_minimum_size.x = 66
		line.add_child(label)
		_stat_labels.append(label)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = rating
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 7)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(bar)
	action = Button.new()
	action.custom_minimum_size = Vector2(96, 48)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.pressed.connect(func() -> void: chosen.emit())
	layout.add_child(action)


func refresh(owned: bool, selected: bool, wallet: int) -> void:
	for index in range(STAT_KEYS.size()):
		_stat_labels[index].text = tr(STAT_KEYS[index])
	if selected:
		action.text = tr("selected")
	elif owned:
		action.text = tr("select")
	else:
		action.text = tr("buy").replace("\\n", "\n") % car.price
	action.disabled = selected or (not owned and car.price > wallet)
	action.focus_mode = Control.FOCUS_NONE if action.disabled else Control.FOCUS_ALL


## A used car shows its condition after the name until it is fully repaired.
func set_condition(percent: int) -> void:
	title.text = car.display_name if percent >= 100 else "%s · %d%%" % [car.display_name, percent]


func set_paint(color: Color) -> void:
	_preview.material.set_shader_parameter("paint", color)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

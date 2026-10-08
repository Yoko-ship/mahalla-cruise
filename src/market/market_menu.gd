class_name MarketMenu
extends Control
## The avtobozor: today's used cars, your number plates and today's plate auction, and
## the workshop for the current car. Emits shop actions upward ("used", "plate",
## "repair"); main validates purchases and saves. Rows are fixed slots refreshed in place.

signal action_chosen(action: String, id: String)
signal closed

const TEXT := Color(1, 0.96, 0.85, 1)
const MUTED := Color(0.78, 0.86, 0.81, 1)
const GOLD := Color(1, 0.85, 0.47, 1)
const SLOTS: int = 3

## Per used-car slot: {"row", "preview", "name", "detail", "button"}.
var used_slots: Array[Dictionary] = []
## Per auction slot: {"row", "plate", "tier", "button"}.
var plate_slots: Array[Dictionary] = []
var title: Label
var wallet_label: Label
var used_label: Label
var none_label: Label
var plates_label: Label
var my_plate: PlateView
var previous_plate: Button
var next_plate: Button
var tip_label: Label
var workshop_label: Label
var repair_button: Button
var back_button: Button
var _catalogue: GarageCatalogue
var _view: Dictionary = {}

@onready var content: VBoxContainer = $Center/Card/Margin/Content


func _ready() -> void:
	title = _label(26, TEXT)
	wallet_label = _label(16, GOLD)
	used_label = _label(13, MUTED)
	content.add_child(title)
	content.add_child(wallet_label)
	content.add_child(used_label)
	for _index in range(SLOTS):
		used_slots.append(_used_slot())
	none_label = _label(13, MUTED)
	none_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(none_label)
	plates_label = _label(13, MUTED)
	content.add_child(plates_label)
	_build_my_plate()
	for _index in range(SLOTS):
		plate_slots.append(_plate_slot())
	workshop_label = _label(13, MUTED)
	content.add_child(workshop_label)
	repair_button = _button(44)
	repair_button.pressed.connect(func() -> void: action_chosen.emit("repair", ""))
	content.add_child(repair_button)
	back_button = _button(50)
	back_button.add_theme_font_size_override("font_size", 19)
	back_button.pressed.connect(close)
	content.add_child(back_button)


## view comes from GarageRules.view().
func set_state(catalogue: GarageCatalogue, view: Dictionary) -> void:
	_catalogue = catalogue
	_view = view.duplicate(true)
	refresh_text()


func open() -> void:
	refresh_text()
	show()
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	back_button.release_focus()
	hide()
	closed.emit()


func refresh_text() -> void:
	if _catalogue == null or _view.is_empty():
		return
	var wallet: int = _view.wallet
	title.text = tr("market")
	wallet_label.text = tr("wallet") % wallet
	used_label.text = tr("used_cars")
	var offers: Array = _view.used_offers
	for index in range(SLOTS):
		_refresh_used(used_slots[index], offers[index] if index < offers.size() else {}, wallet)
	none_label.text = tr("used_none")
	none_label.visible = offers.is_empty()
	plates_label.text = tr("plates")
	my_plate.code = _view.plate
	var multiple: bool = _view.plates.size() > 1
	previous_plate.disabled = not multiple
	next_plate.disabled = not multiple
	var tier := PlateRules.tier(_view.plate)
	tip_label.text = tr("plate_tip") % [tr(PlateRules.TIERS[tier]), tier]
	var auction: Array = _view.plate_offers
	for index in range(SLOTS):
		_refresh_plate(plate_slots[index], auction[index] if index < auction.size() else {}, wallet)
	_refresh_workshop(wallet)
	back_button.text = tr("back")


func _refresh_used(slot: Dictionary, offer: Dictionary, wallet: int) -> void:
	slot.row.visible = not offer.is_empty()
	if offer.is_empty():
		return
	var car := _catalogue.find(offer.car)
	slot.preview.texture = car.texture
	slot.name.text = car.display_name
	slot.detail.text = tr("condition") % offer.condition
	slot.button.text = tr("buy").replace("\\n", "\n") % offer.price
	slot.button.disabled = offer.price > wallet
	slot.button.set_meta("id", offer.car)


func _refresh_plate(slot: Dictionary, offer: Dictionary, wallet: int) -> void:
	slot.row.visible = not offer.is_empty()
	if offer.is_empty():
		return
	slot.plate.code = offer.plate
	slot.tier.text = tr(PlateRules.TIERS[offer.tier])
	var owned: bool = offer.plate in _view.plates
	slot.button.text = tr("owned") if owned else str(offer.price)
	slot.button.disabled = owned or offer.price > wallet
	slot.button.set_meta("id", offer.plate)


func _refresh_workshop(wallet: int) -> void:
	var car := _catalogue.find(_view.selected)
	var percent: int = _view.conditions.get(_view.selected, 100)
	var price: int = _view.repair_price
	if price == 0:
		workshop_label.text = tr("workshop_ok") % car.display_name
	else:
		workshop_label.text = tr("workshop") % [car.display_name, percent]
	repair_button.visible = price > 0
	repair_button.text = tr("repair") % [_catalogue.market.repair_step, price]
	repair_button.disabled = price > wallet


func _cycle_plate(step: int) -> void:
	var owned: Array = _view.plates
	var index := owned.find(_view.plate)
	action_chosen.emit("plate", owned[posmod(index + step, owned.size())])


func _used_slot() -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(30, 46)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var car_name := _label(15, TEXT)
	car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	car_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var detail := _label(12, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(car_name)
	info.add_child(detail)
	var button := _button(44)
	button.custom_minimum_size.x = 96
	button.pressed.connect(func() -> void: action_chosen.emit("used", button.get_meta("id")))
	row.add_child(button)
	return {"row": row, "preview": preview, "name": car_name, "detail": detail, "button": button}


func _plate_slot() -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var plate := PlateView.new()
	plate.custom_minimum_size = Vector2(140, 30)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)
	var tier := _label(12, GOLD)
	tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(tier)
	var button := _button(40)
	button.custom_minimum_size.x = 76
	button.pressed.connect(func() -> void: action_chosen.emit("plate", button.get_meta("id")))
	row.add_child(button)
	return {"row": row, "plate": plate, "tier": tier, "button": button}


func _build_my_plate() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	previous_plate = _button(40)
	previous_plate.text = "<"
	previous_plate.custom_minimum_size.x = 44
	previous_plate.pressed.connect(_cycle_plate.bind(-1))
	my_plate = PlateView.new()
	my_plate.custom_minimum_size = Vector2(0, 38)
	my_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_plate = _button(40)
	next_plate.text = ">"
	next_plate.custom_minimum_size.x = 44
	next_plate.pressed.connect(_cycle_plate.bind(1))
	row.add_child(previous_plate)
	row.add_child(my_plate)
	row.add_child(next_plate)
	tip_label = _label(12, GOLD)
	content.add_child(tip_label)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(height: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 13)
	return button

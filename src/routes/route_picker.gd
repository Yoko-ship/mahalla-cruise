class_name RoutePicker
extends HBoxContainer
## The start screen's city choice. Arrows browse every route; an owned route is chosen at
## once, a locked one shows its price and unlocks when its button is pressed.

signal route_chosen(id: String)
## Whether the browsed route is still locked; the start screen disables Play meanwhile.
signal browsing_locked(locked: bool)

const TEXT := Color(1, 0.91, 0.64, 1)
const PANEL := Color(0.075, 0.175, 0.155, 1)
const BORDER := Color(0.88, 0.81, 0.57, 1)

var routes: Array[RouteDefinition] = []
var index: int = 0
var previous_button := Button.new()
var choice_button := Button.new()
var next_button := Button.new()
var _owned: Array = []
var _wallet: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for button: Button in [previous_button, choice_button, next_button]:
		button.custom_minimum_size = Vector2(44, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 14)
		for state in [
			"font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"
		]:
			button.add_theme_color_override(state, TEXT)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, _style(state))
		add_child(button)
	choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous_button.text = "<"
	next_button.text = ">"
	previous_button.pressed.connect(_browse.bind(-1))
	next_button.pressed.connect(_browse.bind(1))
	choice_button.pressed.connect(_on_choice)


func setup(route_list: Array[RouteDefinition]) -> void:
	routes = route_list
	index = 0


## Shows the selected route unless the player is looking at a locked one.
func refresh(owned: Array, selected: String, wallet: int) -> void:
	_owned = owned
	_wallet = wallet
	if routes.is_empty():
		return
	if shown_route().id in owned:
		for slot in range(routes.size()):
			if routes[slot].id == selected:
				index = slot
	_update()


func shown_route() -> RouteDefinition:
	return routes[index] if not routes.is_empty() else null


func is_locked() -> bool:
	return shown_route() != null and shown_route().id not in _owned


func refresh_text() -> void:
	_update()


func _browse(step: int) -> void:
	index = posmod(index + step, routes.size())
	if not is_locked():
		route_chosen.emit(shown_route().id)
	_update()


func _on_choice() -> void:
	if is_locked():
		route_chosen.emit(shown_route().id)


func _update() -> void:
	var route := shown_route()
	if route == null:
		return
	var text := tr(route.name_key)
	if is_locked():
		text += "\n" + tr("unlock") % route.price
	elif route.bonus_percent() > 0:
		text += "\n" + tr("route_bonus") % route.bonus_percent()
	choice_button.text = text
	choice_button.disabled = is_locked() and route.price > _wallet
	browsing_locked.emit(is_locked())


func _style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL.lightened(0.08) if state in ["hover", "pressed"] else PANEL
	if state == "disabled":
		style.bg_color = PANEL.darkened(0.2)
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

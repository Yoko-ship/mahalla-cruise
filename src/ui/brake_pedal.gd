class_name BrakePedal
extends Control
## The hold-to-brake pedal. It takes its own finger (any touch index) and marks those
## events handled, so a finger on the pedal never steers while another finger drags.

signal held_changed(held: bool)

const PLATE := Color(0.12549, 0.243137, 0.219608, 0.86)
const BORDER := Color(0.88, 0.81, 0.57, 1)
const PEDAL := Color(0.24, 0.25, 0.24, 1)
const PEDAL_HELD := Color(0.78, 0.2, 0.17, 1)
const GRIP := Color(0.08, 0.09, 0.08, 0.8)
const TEXT := Color(1, 0.96, 0.85, 1)

var held: bool = false
var _touch_index: int = -1
var _mouse_held: bool = false
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.bg_color = PLATE
	_box.border_color = BORDER
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(16)


func release() -> void:
	_touch_index = -1
	_mouse_held = false
	_set_held(false)


func refresh_text() -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var handled := false
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _covers(event.position):
			_touch_index = event.index
			handled = true
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			handled = true
	elif event is InputEventScreenDrag:
		handled = event.index == _touch_index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch also sends emulated mouse events; only a real mouse uses this path.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed and _covers(event.position):
				_mouse_held = true
				handled = true
			elif not event.pressed and _mouse_held:
				_mouse_held = false
				handled = true
	elif event is InputEventMouseMotion:
		handled = _mouse_held and event.device != InputEvent.DEVICE_ID_EMULATION
	if handled:
		_set_held(_touch_index != -1 or _mouse_held)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		release()


func _covers(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _set_held(value: bool) -> void:
	if value == held:
		return
	held = value
	queue_redraw()
	held_changed.emit(held)


func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var pedal := Rect2(size.x * 0.22, 10, size.x * 0.56, size.y - 34)
	if held:
		pedal = pedal.grow(-2)
	draw_rect(pedal, PEDAL_HELD if held else PEDAL)
	for row in range(4):
		var y := pedal.position.y + 6 + row * (pedal.size.y - 12) / 3.0
		draw_line(Vector2(pedal.position.x + 5, y), Vector2(pedal.end.x - 5, y), GRIP, 2.0)
	var font := get_theme_default_font()
	draw_string(
		font, Vector2(0, size.y - 9), tr("brake"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, TEXT
	)

class_name SteeringInput
extends Node
## Converts pointer events to relative steering; only one finger owns the gesture.

signal steering_delta(pixels: float)

var _touch_index: int = -1
var _mouse_dragging: bool = false
var _enabled: bool = true


func keyboard_axis() -> float:
	return Input.get_axis("ui_left", "ui_right") if _enabled else 0.0


## The Down arrow brakes on a keyboard; touch uses the HUD brake pedal.
func keyboard_brake() -> bool:
	return _enabled and Input.is_action_pressed("ui_down")


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_input(enabled)
	_reset_gesture()


func _input(event: InputEvent) -> void:
	# Touch also generates mouse events for UI buttons; steer from the real event only.
	if not _enabled or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		steering_delta.emit(event.relative.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		steering_delta.emit(event.relative.x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_gesture()


func _reset_gesture() -> void:
	_touch_index = -1
	_mouse_dragging = false

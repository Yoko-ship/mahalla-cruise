class_name LocationBanner
extends Label
## A brief district name, advanced only by the driving clock supplied by the HUD.

var remaining: float = 0.0
var name_key: String = ""
var _active: bool = false


func show_location(key: String, seconds: float) -> void:
	name_key = key
	remaining = seconds if not key.is_empty() else 0.0
	refresh_text()
	advance(0.0)


func set_active(active: bool) -> void:
	_active = active
	advance(0.0)


func advance(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	visible = _active and remaining > 0.0
	modulate.a = clampf(remaining, 0.0, 1.0)


func refresh_text() -> void:
	text = tr(name_key) if not name_key.is_empty() else ""

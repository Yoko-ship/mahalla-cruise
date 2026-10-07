class_name FeedbackPopup
extends Label
## Brief rising text for pickups and close calls. The HUD keeps it aligned to the road.

const RISE: float = 24.0

var base_y: float = 510.0
var _tween: Tween


func play(message: String) -> void:
	dismiss()
	text = message
	position.y = base_y
	modulate.a = 1.0
	show()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:y", base_y - RISE, 0.85)
	_tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.4)


func dismiss() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	hide()

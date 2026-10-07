class_name PowerUpEffects
extends RefCounted
## Active power-up state for one run. Measured in metres of travel, so pause freezes it.

var magnet_metres: float = 0.0
var double_metres: float = 0.0
var shield: bool = false
var grace_metres: float = 0.0
var _settings: PowerUpSettings


func _init(settings: PowerUpSettings) -> void:
	_settings = settings


func activate(kind: String) -> void:
	match kind:
		"magnet":
			magnet_metres = _settings.magnet_metres
		"double":
			double_metres = _settings.double_metres
		"shield":
			shield = true


func advance(metres: float) -> void:
	magnet_metres = maxf(0.0, magnet_metres - metres)
	double_metres = maxf(0.0, double_metres - metres)
	grace_metres = maxf(0.0, grace_metres - metres)


func multiplier() -> int:
	return 2 if double_metres > 0.0 else 1


func magnet_active() -> bool:
	return magnet_metres > 0.0


## True when a crash is absorbed: by the shield, or during the grace after it broke.
func absorb_crash() -> bool:
	if grace_metres > 0.0:
		return true
	if not shield:
		return false
	shield = false
	grace_metres = _settings.shield_grace_metres
	return true


func is_active() -> bool:
	return magnet_metres > 0.0 or double_metres > 0.0 or shield or grace_metres > 0.0


## Remaining share of each timed effect, and whether the shield is ready.
func view() -> Dictionary:
	return {
		"magnet": magnet_metres / _settings.magnet_metres,
		"double": double_metres / _settings.double_metres,
		"shield": shield,
	}

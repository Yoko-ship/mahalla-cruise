class_name BanknoteDefinition
extends Resource
## Immutable denomination, artwork, and relative spawn frequency.

@export var is_dollar: bool = false
@export_range(1, 1000000) var face_value: int = 1000
@export_range(0.0, 1000.0) var spawn_weight: float = 1.0
@export var texture: Texture2D


func display_name() -> String:
	if is_dollar:
		return "$%d" % face_value
	var digits := str(face_value)
	var label := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			label += " "
		label += digits[index]
	return label + " soʻm"

class_name WheelSettings
extends Resource
## Omad gʻildiragi (the lucky wheel): one free spin a day. Each segment pays points into the
## wallet ("points") or a power-up that starts the next drive ("magnet", "double", "shield").

@export var kinds: Array[String] = []
@export var amounts: Array[int] = []
@export var weights: Array[float] = []
@export var colors: Array[Color] = []
@export_range(0.5, 10.0) var spin_seconds: float = 3.2
## Whole turns before the wheel settles on the prize.
@export_range(1, 12) var spin_turns: int = 5


func size() -> int:
	return kinds.size()


## The segment a roll in [0, 1) lands on, by weight.
func pick(roll: float) -> int:
	assert(kinds.size() == amounts.size() and kinds.size() == weights.size())
	var total := 0.0
	for weight in weights:
		total += weight
	var target := clampf(roll, 0.0, 0.999999) * total
	for index in range(weights.size()):
		target -= weights[index]
		if target < 0.0:
			return index
	return weights.size() - 1

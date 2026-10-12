class_name WeddingSettings
extends Resource
## Toʻy korteji: a decorated wedding convoy that cruises ahead in one lane while guests throw
## sochqi (money) behind it. It never reaches the player; traffic waits while it is on the road.

@export_range(0.0, 20000.0) var first_metres: float = 700.0
@export_range(50.0, 20000.0) var convoy_metres_min: float = 1100.0
@export_range(50.0, 20000.0) var convoy_metres_max: float = 1600.0
@export_range(1, 5) var cars: int = 3
## Centre-to-centre spacing of the convoy cars.
@export_range(60.0, 200.0) var car_gap: float = 86.0
## Screen y of the last car while cruising; well above the player.
@export var cruise_y: float = 250.0
## Screen pixels per pixel of road travel while arriving and while driving off.
@export_range(0.1, 2.0) var arrive_rate: float = 0.6
@export_range(0.1, 2.0) var leave_rate: float = 0.7
## Road travel spent cruising and throwing sochqi.
@export_range(10.0, 2000.0) var cruise_metres: float = 150.0
## Road travel between handfuls, notes per handful, and their sideways spread.
@export_range(40.0, 2000.0) var toss_pixels: float = 170.0
@export_range(1, 5) var notes_per_toss: int = 3
@export_range(0.0, 40.0) var toss_spread: float = 30.0
## Gap behind the last car where notes land, plus random extra depth.
@export_range(0.0, 120.0) var toss_gap: float = 30.0
@export_range(0.0, 80.0) var toss_depth: float = 26.0
## Soʻm face values thrown, with matching weights.
@export var toss_values: Array[int] = [1000, 5000, 10000]
@export var toss_weights: Array[float] = [65.0, 28.0, 7.0]
@export var spawn_y: float = -80.0
@export var collision_half_size := Vector2(20, 36)


func pick_value(roll: float) -> int:
	assert(toss_values.size() == toss_weights.size() and not toss_values.is_empty())
	var total := 0.0
	for weight in toss_weights:
		total += weight
	var target := clampf(roll, 0.0, 0.999999) * total
	for index in range(toss_values.size()):
		target -= toss_weights[index]
		if target < 0.0:
			return toss_values[index]
	return toss_values.back()

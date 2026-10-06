class_name PickupSettings
extends Resource
## Money values and spawn tuning. Shared settings are immutable during a run.

@export var som_notes: Array[BanknoteDefinition] = []
@export var dollar_note: BanknoteDefinition
@export_range(1, 10000) var som_per_point: int = 1000
@export_range(1, 10000) var dollar_points_per_unit: int = 10
@export_range(0.0, 1.0) var dollar_chance: float = 0.12
@export_range(1.0, 2000.0) var first_spawn_distance: float = 80.0
@export_range(80.0, 2000.0) var spawn_distance: float = 200.0
@export_range(1, 12) var max_pickups: int = 6
@export var spawn_y: float = -32.0
@export var despawn_y: float = 816.0
@export var collision_half_size := Vector2(17, 12)
@export_range(0.0, 200.0) var traffic_clearance: float = 80.0


func points_for(note: BanknoteDefinition) -> int:
	if note.is_dollar:
		return note.face_value * dollar_points_per_unit
	return floori(float(note.face_value) / som_per_point)


func select_note(dollar: bool, roll: float) -> BanknoteDefinition:
	if dollar:
		return dollar_note
	var total: float = 0.0
	for note in som_notes:
		total += note.spawn_weight
	assert(total > 0.0, "Soʻm notes require a positive total spawn weight")
	var target := clampf(roll, 0.0, 0.999999) * total
	for note in som_notes:
		target -= note.spawn_weight
		if target < 0.0:
			return note
	return som_notes.back()

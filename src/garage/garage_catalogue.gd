class_name GarageCatalogue
extends Resource
## Ordered car roster. Only cars with artwork are offered to players.

@export var cars: Array[CarDefinition] = []
@export var paints: Array[PaintDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []


func find(id: String) -> CarDefinition:
	for car in cars:
		if car.id == id and car.is_available():
			return car
	return null


func find_paint(id: String) -> PaintDefinition:
	for paint in paints:
		if paint.id == id:
			return paint
	return null


func find_upgrade(id: String) -> UpgradeDefinition:
	for upgrade in upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func available() -> Array[CarDefinition]:
	var result: Array[CarDefinition] = []
	for car in cars:
		if car.is_available():
			result.append(car)
	return result

class_name GarageCatalogue
extends Resource
## Everything the player can buy: the ordered car roster (only cars with artwork are
## offered), paints, upgrades, city routes, number plates, and the used-car market.

@export var cars: Array[CarDefinition] = []
@export var paints: Array[PaintDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var routes: Array[RouteDefinition] = []
@export var plates: PlateSettings
@export var market: MarketSettings


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


func find_route(id: String) -> RouteDefinition:
	for route in routes:
		if route.id == id:
			return route
	return null


func available() -> Array[CarDefinition]:
	var result: Array[CarDefinition] = []
	for car in cars:
		if car.is_available():
			result.append(car)
	return result

class_name GarageCatalogue
extends Resource
## Ordered car roster. Only cars with artwork are offered to players.

@export var cars: Array[CarDefinition] = []


func find(id: String) -> CarDefinition:
	for car in cars:
		if car.id == id and car.is_available():
			return car
	return null


func available() -> Array[CarDefinition]:
	var result: Array[CarDefinition] = []
	for car in cars:
		if car.is_available():
			result.append(car)
	return result

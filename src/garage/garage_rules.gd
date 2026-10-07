class_name GarageRules
extends RefCounted
## Garage purchase and selection rules. Main passes the catalogue and the store explicitly.


static func current_car(catalogue: GarageCatalogue, store: LocalProgressStore) -> CarDefinition:
	# A saved car without artwork falls back to the default without rewriting the save.
	var car := catalogue.find(store.selected_car)
	return car if car != null else catalogue.find(ProgressData.DEFAULT_CAR)


static func current_paint(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> PaintDefinition:
	var paint := catalogue.find_paint(str(store.paints.get(car.id, "")))
	if paint == null or not owns_paint(store, car, paint.id):
		paint = catalogue.find_paint(car.factory_paint)
	return paint


static func owns_paint(store: LocalProgressStore, car: CarDefinition, paint_id: String) -> bool:
	return paint_id == car.factory_paint or paint_id in store.owned_paints


static func choose_car(catalogue: GarageCatalogue, store: LocalProgressStore, id: String) -> bool:
	var choice := catalogue.find(id)
	if choice == null:
		return false
	if id in store.owned_cars:
		store.select_car(id)
		return true
	return store.buy_car(id, choice.price)


static func choose_paint(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition, id: String
) -> bool:
	var paint := catalogue.find_paint(id)
	if paint == null:
		return false
	if owns_paint(store, car, id):
		store.select_paint(car.id, id)
		return true
	return store.buy_paint(car.id, id, paint.price)


## Everything the garage screens need, as plain values.
static func view(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> Dictionary:
	var colors := {}
	for other in catalogue.available():
		colors[other.id] = current_paint(catalogue, store, other).color
	var owned_paints: Array[String] = []
	for paint in catalogue.paints:
		if owns_paint(store, car, paint.id):
			owned_paints.append(paint.id)
	return {
		"owned": store.owned_cars.duplicate(),
		"selected": car.id,
		"wallet": store.wallet,
		"paint": current_paint(catalogue, store, car).id,
		"owned_paints": owned_paints,
		"colors": colors,
	}

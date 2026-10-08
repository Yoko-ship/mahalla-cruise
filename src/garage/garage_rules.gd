class_name GarageRules
extends RefCounted
## Garage purchase and selection rules. Main passes the catalogue and the store explicitly.
## apply() is the single entry for every shop action (garage, market, plates, routes).


## action: "car", "paint", "upgrade", "route", "plate" (choose or buy), "used" (buy a
## market car), or "repair" (the current car). Returns whether anything changed.
static func apply(
	action: String,
	id: String,
	catalogue: GarageCatalogue,
	store: LocalProgressStore,
	car: CarDefinition,
	day: String = DailyTasks.today()
) -> bool:
	match action:
		"car":
			return choose_car(catalogue, store, id)
		"paint":
			return choose_paint(catalogue, store, car, id)
		"upgrade":
			return UpgradeRules.choose(catalogue, store, car, id)
		"route":
			return RouteRules.choose(catalogue, store, id)
		"plate":
			var region := RouteRules.current(catalogue, store).region_code
			return PlateRules.choose(catalogue.plates, store, region, id, day)
		"used":
			return MarketRules.buy_used(catalogue, store, id, day)
		"repair":
			return MarketRules.repair(catalogue, store, car)
	return false


## What the drive needs from the garage: tuned settings, paint, upgrade and condition
## multipliers, plate (with its taxi tip), and the route.
static func drive_setup(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> Dictionary:
	var boosts := UpgradeRules.boosts(catalogue, store, car)
	var wear := MarketRules.condition_factor(catalogue.market, MarketRules.condition(store, car))
	boosts.handling *= wear
	boosts.tank *= wear
	boosts.plate = store.plate
	boosts.tips = PlateRules.tier(store.plate)
	return {
		"settings": UpgradeRules.tuned_settings(car.settings, boosts),
		"paint": current_paint(catalogue, store, car).color,
		"boosts": boosts,
		"route": RouteRules.current(catalogue, store),
	}


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
	# Buying also applies the paint to the current car in the same write.
	return store.spend(
		paint.price,
		func() -> void:
			store.owned_paints.append(id)
			store.paints[car.id] = id
	)


## Everything the garage, market, and start screens need, as plain values.
static func view(
	catalogue: GarageCatalogue,
	store: LocalProgressStore,
	car: CarDefinition,
	day: String = DailyTasks.today()
) -> Dictionary:
	var colors := {}
	var conditions := {}
	for other in catalogue.available():
		colors[other.id] = current_paint(catalogue, store, other).color
		conditions[other.id] = MarketRules.condition(store, other)
	var route := RouteRules.current(catalogue, store)
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
		"upgrades": UpgradeRules.levels(catalogue, store, car),
		"plate": store.plate,
		"plates": store.owned_plates.duplicate(),
		"plate_offers": PlateRules.offers(catalogue.plates, route.region_code, day),
		"used_offers": MarketRules.used_offers(catalogue, store, day),
		"conditions": conditions,
		"repair_price": MarketRules.repair_price(catalogue, store, car),
		"routes": store.owned_routes.duplicate(),
		"route": route.id,
	}

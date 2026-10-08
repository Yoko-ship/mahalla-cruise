class_name MarketRules
extends RefCounted
## Used cars on the avtobozor and the workshop. Offers change daily; condition lowers
## steering and tank size until repaired. Main passes the catalogue and the store.


## Up to `offers` cars the player does not own, each with a condition and price.
static func used_offers(
	catalogue: GarageCatalogue, store: LocalProgressStore, day: String
) -> Array[Dictionary]:
	var settings := catalogue.market
	var random := RandomNumberGenerator.new()
	random.seed = hash("bozor:" + day)
	var result: Array[Dictionary] = []
	for car in catalogue.available():
		var span := settings.condition_max - settings.condition_min
		var steps := floori(float(span) / settings.condition_step)
		var condition := (
			settings.condition_min + settings.condition_step * random.randi_range(0, steps)
		)
		if car.price <= 0 or car.id in store.owned_cars or result.size() >= settings.offers:
			continue
		var price := car.price * settings.used_price_share * condition / 100.0
		result.append({"car": car.id, "condition": condition, "price": roundi(price / 10.0) * 10})
	return result


static func buy_used(
	catalogue: GarageCatalogue, store: LocalProgressStore, id: String, day: String
) -> bool:
	for offer in used_offers(catalogue, store, day):
		if offer.car == id:
			return store.spend(
				offer.price,
				func() -> void:
					store.owned_cars.append(id)
					store.selected_car = id
					store.conditions[id] = offer.condition
			)
	return false


static func condition(store: LocalProgressStore, car: CarDefinition) -> int:
	return clampi(int(store.conditions.get(car.id, 100)), 1, 100)


## Steering and tank multiplier for a condition percent.
static func condition_factor(settings: MarketSettings, percent: int) -> float:
	return lerpf(settings.worn_factor, 1.0, clampi(percent, 0, 100) / 100.0)


## Price of one repair step for this car, or 0 when it is already like new.
static func repair_price(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> int:
	if condition(store, car) >= 100:
		return 0
	var settings := catalogue.market
	var price := roundi(car.price * settings.repair_price_share / 10.0) * 10
	return maxi(settings.repair_price_min, price)


static func repair(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> bool:
	var price := repair_price(catalogue, store, car)
	if price == 0:
		return false
	var repaired := mini(100, condition(store, car) + catalogue.market.repair_step)
	return store.spend(
		price,
		func() -> void:
			if repaired >= 100:
				store.conditions.erase(car.id)
			else:
				store.conditions[car.id] = repaired
	)

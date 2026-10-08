class_name UpgradeRules
extends RefCounted
## Per-car upgrade purchases and their effects. Main passes the catalogue and store.


static func level(store: LocalProgressStore, car: CarDefinition, upgrade: UpgradeDefinition) -> int:
	var levels: Dictionary = store.upgrades.get(car.id, {})
	return clampi(int(levels.get(upgrade.id, 0)), 0, upgrade.max_level())


## Buys the next level when it exists and the wallet covers it.
static func choose(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition, id: String
) -> bool:
	var upgrade := catalogue.find_upgrade(id)
	if upgrade == null:
		return false
	var current := level(store, car, upgrade)
	if current >= upgrade.max_level():
		return false
	return store.buy_upgrade(car.id, id, upgrade.price_for(current))


static func levels(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> Dictionary:
	var result := {}
	for upgrade in catalogue.upgrades:
		result[upgrade.id] = level(store, car, upgrade)
	return result


## Multipliers for the drive, keyed by upgrade id; missing upgrades count as 1.
static func boosts(
	catalogue: GarageCatalogue, store: LocalProgressStore, car: CarDefinition
) -> Dictionary:
	var result := {"handling": 1.0, "tank": 1.0, "suspension": 1.0}
	for upgrade in catalogue.upgrades:
		result[upgrade.id] = upgrade.multiplier(level(store, car, upgrade))
	return result


## A tuned copy when handling is upgraded; shared car settings are never changed.
static func tuned_settings(settings: CarSettings, boosts: Dictionary) -> CarSettings:
	var handling: float = boosts.get("handling", 1.0)
	if is_equal_approx(handling, 1.0):
		return settings
	var tuned := settings.duplicate() as CarSettings
	tuned.steering_speed *= handling
	return tuned

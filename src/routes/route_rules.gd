class_name RouteRules
extends RefCounted
## Route unlocks and selection. Main passes the catalogue and the store explicitly.


static func current(catalogue: GarageCatalogue, store: LocalProgressStore) -> RouteDefinition:
	var route := catalogue.find_route(store.route)
	if route == null or route.id not in store.owned_routes:
		route = catalogue.find_route(ProgressData.DEFAULT_ROUTE)
	return route


## Selects an owned route, or unlocks and selects it when the wallet covers the price.
static func choose(catalogue: GarageCatalogue, store: LocalProgressStore, id: String) -> bool:
	var route := catalogue.find_route(id)
	if route == null:
		return false
	if id in store.owned_routes:
		if id != store.route or store.has_unsaved_changes:
			store.update(func() -> void: store.route = id)
		return true
	return store.spend(
		route.price,
		func() -> void:
			store.owned_routes.append(id)
			store.route = id
	)

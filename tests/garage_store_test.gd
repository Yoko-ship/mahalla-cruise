extends SceneTree

const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://garage_store_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_roster()
	_test_wallet_and_purchases()
	_test_compatibility()
	_test_write_failure()
	_cleanup()
	if failures == 0:
		print(
			(
				"PASS: car roster, wallet, purchases, and garage save compatibility (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_roster() -> void:
	var ids: Array[String] = []
	var prices: Array[int] = []
	for car in GARAGE.cars:
		ids.append(car.id)
		prices.append(car.price)
		_check(car.settings != null, "Every car has handling settings: " + car.id)
		for rating in [car.speed_rating(), car.control_rating(), car.size_rating()]:
			_check(rating >= 0.0 and rating <= 1.0, "Stat ratings stay in range: " + car.id)
	_check(ids == ["damas", "matiz", "cobalt", "gentra"], "Roster is Damas, Matiz, Cobalt, Gentra")
	_check(prices == [0, 300, 1000, 2500], "Damas is free and later cars cost more")
	for id in ids:
		_check(GARAGE.find(id) != null, "Car has (placeholder) artwork: " + id)
	var gentra_art := GARAGE.cars[3].texture
	var hidden := GARAGE.cars[3].duplicate() as CarDefinition
	hidden.texture = null
	var partial := GarageCatalogue.new()
	partial.cars = [GARAGE.cars[0], hidden]
	_check(partial.find("gentra") == null, "Cars without artwork stay hidden")
	_check(partial.available().size() == 1, "Only cars with artwork are offered")
	_check(GARAGE.cars[3].texture == gentra_art, "Hiding a copy never changes the shared roster")
	for a in GARAGE.cars:
		for b in GARAGE.cars:
			if a == b:
				continue
			var dominates := (
				a.speed_rating() >= b.speed_rating()
				and a.control_rating() >= b.control_rating()
				and a.size_rating() <= b.size_rating()
			)
			_check(not dominates, "%s is not strictly better than %s" % [a.id, b.id])
	var matiz := GARAGE.cars[1]
	var gentra := GARAGE.cars[3]
	_check(matiz.size_rating() < gentra.size_rating(), "Matiz is the compact car")
	_check(gentra.speed_rating() > matiz.speed_rating(), "Gentra is faster than Matiz")


func _test_wallet_and_purchases() -> void:
	var store := _store()
	_check(store.wallet == 0 and store.owned_cars == ["damas"], "New installs own only Damas")
	_check(store.selected_car == "damas", "New installs drive the Damas")
	_check(store.complete_run(120), "A first scored run is also a record")
	_check(store.wallet == 120 and store.best_score == 120, "Run points enter the wallet")
	_check(not store.complete_run(50), "A lower run is not a record")
	_check(store.wallet == 170 and store.best_score == 120, "Every finished run adds to the wallet")
	_check(not store.complete_run(-5) and store.wallet == 170, "Negative runs never change it")
	_check(not store.buy_car("matiz", 300), "Cars cannot be bought without enough points")
	_check(
		store.wallet == 170 and "matiz" not in store.owned_cars, "Failed purchase changes nothing"
	)
	store.complete_run(200)
	_check(store.buy_car("matiz", 300), "An affordable car can be bought")
	_check(store.wallet == 70, "Buying spends the price")
	_check(store.owned_cars == ["damas", "matiz"], "Bought cars are owned")
	_check(store.selected_car == "matiz", "Buying selects the new car")
	_check(not store.buy_car("matiz", 0), "An owned car cannot be bought twice")
	store.select_car("damas")
	_check(store.selected_car == "damas", "Owned cars can be selected again")
	store.select_car("gentra")
	_check(store.selected_car == "damas", "Unowned cars cannot be selected")
	var reopened := _store()
	_check(
		reopened.wallet == 70 and reopened.best_score == 200, "Wallet and record survive relaunch"
	)
	_check(reopened.owned_cars == ["damas", "matiz"], "Owned cars survive relaunch")
	_check(reopened.selected_car == "damas", "The selected car survives relaunch")
	store.free()
	reopened.free()


func _test_compatibility() -> void:
	_write('{"version": 1, "stats": {"best_score": 55}}')
	var store := _store()
	_check(store.best_score == 55 and store.wallet == 0, "Saves from before the garage still load")
	_check(store.owned_cars == ["damas"], "Older saves start with the Damas")
	store.free()
	_write(
		(
			'{"version": 1, "stats": {"best_score": 7}, "garage": {"wallet": -5, "owned": "x",'
			+ ' "selected": "gentra", "future": 1}}'
		)
	)
	store = _store()
	_check(store.best_score == 7, "A damaged garage never loses the record")
	_check(store.wallet == 0 and store.owned_cars == ["damas"], "Invalid garage fields fall back")
	_check(store.selected_car == "damas", "An unowned saved selection falls back to the Damas")
	store.complete_run(3)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
	_check(saved.garage.get("future") == 1, "Unknown garage fields survive writes")
	_check(int(saved.garage.wallet) == 3, "The repaired wallet is saved")
	store.free()
	_write(
		(
			(
				'{"version": 1, "stats": {"best_score": 0}, "garage": {"wallet": %d,'
				% (ProgressData.MAX_SCORE - 1)
			)
			+ ' "owned": ["damas", "nexia", 4], "selected": "nexia"}}'
		)
	)
	store = _store()
	_check(store.owned_cars == ["damas", "nexia"], "Unknown car ids are kept for later versions")
	_check(store.selected_car == "nexia", "A saved future selection is kept in storage")
	store.complete_run(10)
	_check(store.wallet == ProgressData.MAX_SCORE, "The wallet is capped instead of overflowing")
	store.free()


func _test_write_failure() -> void:
	var store := LocalProgressStore.new()
	store.save_path = "user://missing_garage_dir_%d/progress.json" % OS.get_process_id()
	store.load_progress()
	store.complete_run(40)
	_check(store.wallet == 40 and store.has_unsaved_changes, "Failed writes keep the wallet")
	_check(store.buy_car("matiz", 30), "Purchases still work during a failed-save session")
	_check(store.has_unsaved_changes and store.wallet == 10, "The purchase is pending a retry")
	store.free()


func _store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _write(text: String) -> void:
	_cleanup()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

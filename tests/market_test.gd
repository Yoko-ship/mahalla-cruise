extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const DAY: String = "2026-10-08"

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://market_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_offers()
	_test_buying_and_repair()
	_test_condition_effects()
	await _test_screens()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: used-car market, condition, workshop, saving, and layout (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_offers() -> void:
	var store := LocalProgressStore.new()
	var market := GARAGE.market
	var offers := MarketRules.used_offers(GARAGE, store, DAY)
	_check(offers == MarketRules.used_offers(GARAGE, store, DAY), "Offers are fixed for the day")
	_check(offers.size() == 3, "Three cars on sale when none are owned")
	var conditions_seen := {}
	for day in range(1, 29):
		for offer in MarketRules.used_offers(GARAGE, store, "2026-11-%02d" % day):
			var car := GARAGE.find(offer.car)
			var condition: int = offer.condition
			conditions_seen[condition] = true
			_check(car != null and car.price > 0, "Only paid cars are sold used")
			_check(condition >= market.condition_min and condition <= market.condition_max, "Range")
			_check(condition % market.condition_step == 0, "Condition in 5% steps")
			var expected := roundi(car.price * 0.7 * condition / 100.0 / 10.0) * 10
			_check(offer.price == expected and offer.price < car.price, "Used price is lower")
	_check(conditions_seen.size() >= 5, "Conditions vary from day to day")
	store.owned_cars.append("matiz")
	var without := MarketRules.used_offers(GARAGE, store, DAY)
	_check(without.size() == 2, "Owned cars are not offered")
	for offer in without:
		_check(offer.car != "matiz", "Matiz is owned")
	var same := true
	for offer in without:
		for earlier in offers:
			if earlier.car == offer.car:
				same = same and earlier.condition == offer.condition
	_check(same, "Each car keeps its condition when another is bought")
	store.owned_cars.append_array(["cobalt", "gentra"])
	_check(MarketRules.used_offers(GARAGE, store, DAY).is_empty(), "No offers when all are owned")
	store.free()


func _test_buying_and_repair() -> void:
	_cleanup()
	var store := _store()
	var offer: Dictionary = MarketRules.used_offers(GARAGE, store, DAY)[0]
	var damas := GARAGE.find("damas")
	_check(not GarageRules.apply("used", offer.car, GARAGE, store, damas, DAY), "Needs points")
	store.complete_run(offer.price + 500)
	_check(GarageRules.apply("used", offer.car, GARAGE, store, damas, DAY), "A used car is bought")
	_check(store.wallet == 500, "It costs the used price")
	_check(store.selected_car == offer.car and offer.car in store.owned_cars, "Owned and selected")
	_check(store.conditions[offer.car] == offer.condition, "It keeps its condition")
	_check(not GarageRules.apply("used", offer.car, GARAGE, store, damas, DAY), "Bought once")
	var car := GARAGE.find(offer.car)
	var price := MarketRules.repair_price(GARAGE, store, car)
	_check(price == maxi(20, roundi(car.price * 0.06 / 10.0) * 10), "Repair price")
	_check(GarageRules.apply("repair", "", GARAGE, store, car, DAY), "The workshop repairs")
	_check(store.conditions[offer.car] == offer.condition + 10, "One repair adds 10%")
	_check(store.wallet == 500 - price, "Repairs cost points")
	store.complete_run(100000)
	while store.conditions.has(offer.car):
		GarageRules.apply("repair", "", GARAGE, store, car, DAY)
	_check(MarketRules.condition(store, car) == 100, "Repairs reach 100%")
	_check(MarketRules.repair_price(GARAGE, store, car) == 0, "A car like new needs no repair")
	_check(not GarageRules.apply("repair", "", GARAGE, store, car, DAY), "Nothing to repair")
	_check(MarketRules.repair_price(GARAGE, store, damas) == 0, "Damas starts like new")
	store.conditions["matiz"] = 55
	store.update(func() -> void: pass)
	var reopened := _store()
	_check(reopened.conditions == {"matiz": 55}, "Conditions survive relaunch")
	store.free()
	reopened.free()
	_write(
		(
			'{"version": 1, "stats": {"best_score": 4}, "garage": {"conditions": {"matiz": 140,'
			+ ' "cobalt": 60, "gentra": "x", "damas": 0}}}'
		)
	)
	store = _store()
	_check(store.best_score == 4 and store.conditions == {"cobalt": 60}, "Damaged values dropped")
	store.free()


func _test_condition_effects() -> void:
	var store := LocalProgressStore.new()
	store.owned_cars.append("matiz")
	store.selected_car = "matiz"
	store.conditions["matiz"] = 50
	var matiz := GARAGE.find("matiz")
	var setup := GarageRules.drive_setup(GARAGE, store, matiz)
	_check(is_equal_approx(setup.boosts.handling, 0.85), "50% condition steers at 85%")
	_check(is_equal_approx(setup.boosts.tank, 0.85), "and holds 85% of the fuel")
	var settings: CarSettings = setup.settings
	_check(is_equal_approx(settings.steering_speed, matiz.settings.steering_speed * 0.85), "Copy")
	_check(is_equal_approx(matiz.settings.steering_speed, 780.0), "Shared settings never change")
	store.conditions.erase("matiz")
	var fresh := GarageRules.drive_setup(GARAGE, store, matiz)
	_check(fresh.settings == matiz.settings, "A car like new drives on its own settings")
	store.free()


func _test_screens() -> void:
	_cleanup()
	var game := _game(_path)
	game.progress.wallet = 5000
	game.garage_action("car", "damas")
	var offer: Dictionary = MarketRules.used_offers(GARAGE, game.progress, DailyTasks.today())[0]
	game.open_garage()
	await _click(game.hud.garage_menu.market_button)
	var market := game.hud.market_menu
	_check(market.used_slots[0].name.text == GARAGE.find(offer.car).display_name, "Offer shown")
	_check(market.used_slots[0].detail.text == "Condition %d%%" % offer.condition, "Condition")
	_check(not market.repair_button.visible, "Damas needs no repair")
	await _click(market.used_slots[0].button)
	_check(game.car.id == offer.car, "A real click buys and drives the used car")
	_check(game.progress.wallet == 5000 - offer.price, "The used price is paid")
	_check(market.repair_button.visible, "The workshop offers a repair")
	var tank := game.world.fuel.capacity_metres
	await _click(market.repair_button)
	_check(game.progress.conditions.get(offer.car, 100) > offer.condition, "A click repairs")
	_check(game.world.fuel.capacity_metres > tank, "Repairs restore the tank at once")
	await _click(market.back_button)
	var row := game.hud.garage_menu.row_for(offer.car)
	var percent: int = game.progress.conditions.get(offer.car, 100)
	_check(row.title.text == "%s · %d%%" % [offer.car.capitalize(), percent], "Garage condition")
	game.hud.garage_menu.close()
	game.start_run()
	var wallet := game.progress.wallet
	game.garage_action("repair", "")
	_check(game.progress.wallet == wallet, "No repairs during a drive")
	game.free()


func _test_layout(locale: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language(locale)
	game.progress.wallet = 1234567
	game.progress.owned_cars.append("matiz")
	game.progress.selected_car = "matiz"
	game.progress.conditions["matiz"] = 55
	game.progress.owned_plates.append("01A777AA")
	game.garage_action("car", "matiz")
	game.open_garage()
	game.hud.garage_menu.market_pressed.emit()
	for _frame in range(3):
		await process_frame
	var market := game.hud.market_menu
	var card := market.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Market fits: " + locale)
	var texts: Array[Label] = [market.tip_label, market.workshop_label, market.used_label]
	for slot in market.used_slots:
		texts.append(slot.detail)
	for slot in market.plate_slots:
		texts.append(slot.tier)
	for label in texts:
		var font := label.get_theme_font("font")
		var size := label.get_theme_font_size("font_size")
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_check(width <= label.size.x + 1.0, "Text fits (%s): %s" % [locale, label.text])
	for button in [market.repair_button, market.used_slots[0].button, market.plate_slots[0].button]:
		_check(button.size.y >= 40.0, "Market buttons are touch-sized: " + locale)
	view.free()


func _game(path: String) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = path
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	return game


func _store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


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

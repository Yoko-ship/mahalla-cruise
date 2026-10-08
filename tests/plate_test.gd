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
	_path = "user://plate_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_format_and_tiers()
	_test_auction()
	_test_buying_and_saving()
	await _test_game_plate()
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: number plates, rarity, daily auction, saving, and taxi tips (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_format_and_tiers() -> void:
	_check(PlateRules.format("01A777AA") == "01 A 777 AA", "Plates read like real ones")
	var tiers := {
		"01A482DM": 0,
		"30B121KM": 1,
		"01S482SS": 1,
		"01A555KM": 2,
		"80A007KM": 2,
		"01A777AA": 3,
		"90X001XX": 3,
	}
	for code: String in tiers:
		_check(PlateRules.tier(code) == tiers[code], "Tier of %s" % code)
	for code in ["01A000AA", "1A777AA", "01a777AA", "0XA777AA", "01A77AAA", ""]:
		_check(not ProgressData.is_plate(code), "Invalid plate refused: %s" % code)
	_check(ProgressData.is_plate(ProgressData.DEFAULT_PLATE), "The starting plate is valid")
	_check(PlateRules.tier(ProgressData.DEFAULT_PLATE) == 0, "Everyone starts with a common plate")


func _test_auction() -> void:
	var settings := GARAGE.plates
	var offers := PlateRules.offers(settings, "30", DAY)
	_check(offers == PlateRules.offers(settings, "30", DAY), "The same day gives the same plates")
	_check(offers != PlateRules.offers(settings, "30", "2026-10-09"), "A new day, new plates")
	_check(offers.size() == 3, "Three plates a day")
	_check(offers[0].tier == 0 and offers[1].tier == 1 and offers[2].tier >= 2, "Rising rarity")
	var legendary := 0
	for day in range(1, 61):
		var auction := PlateRules.offers(
			settings, "01", "2026-11-%02d" % ((day % 28) + 1) + str(day)
		)
		for offer in auction:
			_check(ProgressData.is_plate(offer.plate), "Auction plates are valid")
			_check(offer.plate.begins_with("01"), "Auction plates use the route's region")
			_check(offer.price == settings.price_for(offer.tier), "Price follows the tier")
		legendary += int(auction[2].tier == 3)
	_check(legendary > 5 and legendary < 40, "Legendary plates are rare (%d of 60)" % legendary)
	_check(settings.tier_prices == [150, 600, 2000, 6000], "Tier prices")


func _test_buying_and_saving() -> void:
	_cleanup()
	var store := _store()
	var damas := GARAGE.find("damas")
	var offers := PlateRules.offers(GARAGE.plates, "01", DAY)
	var nice: String = offers[1].plate
	_check(not GarageRules.apply("plate", nice, GARAGE, store, damas, DAY), "Plates need points")
	store.complete_run(1000)
	_check(GarageRules.apply("plate", nice, GARAGE, store, damas, DAY), "An offer is bought")
	_check(store.wallet == 400 and store.plate == nice, "Buying spends 600 and fits the plate")
	_check(not GarageRules.apply("plate", "01A111AA", GARAGE, store, damas, DAY), "Only offers")
	var old := ProgressData.DEFAULT_PLATE
	_check(GarageRules.apply("plate", old, GARAGE, store, damas, DAY), "Owned plates switch")
	_check(store.wallet == 400 and store.plate == old, "Switching is free")
	var reopened := _store()
	_check(reopened.owned_plates == [old, nice], "Owned plates survive relaunch")
	_check(reopened.plate == old, "The fitted plate survives relaunch")
	store.free()
	reopened.free()
	_write(
		(
			'{"version": 1, "stats": {"best_score": 3}, "garage": {"plates": ["01A777AA", "bad", 4],'
			+ ' "plate": "30B121KM"}}'
		)
	)
	store = _store()
	_check(store.best_score == 3, "Damaged plate fields keep the record")
	_check(store.owned_plates == [old, "01A777AA"], "Only valid plates load")
	_check(store.plate == old, "A plate that is not owned falls back")
	store.free()


func _test_game_plate() -> void:
	_cleanup()
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	_check(game.world.player.visual.plate == ProgressData.DEFAULT_PLATE, "The car wears its plate")
	_check(game.hud.menu.plate_view.code == ProgressData.DEFAULT_PLATE, "The start screen shows it")
	_check(game.world.taxi.tip_notes == 0, "A common plate earns no tip")
	game.progress.wallet = 20000
	game.garage_action("car", "damas")
	var offers := PlateRules.offers(GARAGE.plates, "01", DailyTasks.today())
	var top: String = offers[2].plate
	game.open_garage()
	await _click(game.hud.garage_menu.market_button)
	var market := game.hud.market_menu
	_check(market.visible and not game.hud.garage_menu.visible, "The garage opens the market")
	await _click(market.plate_slots[2].button)
	_check(game.progress.plate == top, "A real click buys the top plate")
	_check(game.world.player.visual.plate == top, "The new plate goes on the car at once")
	_check(game.world.taxi.tip_notes == PlateRules.tier(top), "Rarer plates earn taxi tips")
	_check(market.my_plate.code == top, "The market shows the fitted plate")
	_check(market.plate_slots[2].button.text == "Owned", "A bought plate shows as owned")
	await _click(market.previous_plate)
	_check(game.progress.plate == ProgressData.DEFAULT_PLATE, "Arrows switch between plates")
	_check(market.tip_label.text == "Common · taxi tip +0", "The tip line follows the plate")
	await _click(market.back_button)
	_check(game.hud.garage_menu.visible, "Back returns to the garage")
	game.free()


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

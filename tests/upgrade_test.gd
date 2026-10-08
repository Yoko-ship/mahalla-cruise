extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://upgrade_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_catalogue()
	_test_rules_and_storage()
	_test_effects()
	await _test_garage_buttons()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: car upgrades, prices, saving, effects, and garage buttons (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_catalogue() -> void:
	var ids: Array[String] = []
	for upgrade in GARAGE.upgrades:
		ids.append(upgrade.id)
		_check(upgrade.max_level() == 3, "Three levels: " + upgrade.id)
		var rising := (
			upgrade.prices[0] < upgrade.prices[1] and upgrade.prices[1] < upgrade.prices[2]
		)
		_check(rising, "Each level costs more: " + upgrade.id)
	_check(ids == ["handling", "tank", "suspension"], "Handling, tank, and suspension")
	var suspension := GARAGE.find_upgrade("suspension")
	_check(is_equal_approx(suspension.multiplier(3), 0.25), "Full suspension keeps 25% penalty")
	_check(is_equal_approx(GARAGE.find_upgrade("handling").multiplier(3), 1.3), "Handling +30%")
	_check(is_equal_approx(GARAGE.find_upgrade("tank").multiplier(2), 1.5), "Tank +25% a level")


func _test_rules_and_storage() -> void:
	_cleanup()
	var store := _store()
	var damas := GARAGE.find("damas")
	var matiz := GARAGE.find("matiz")
	_check(not UpgradeRules.choose(GARAGE, store, damas, "handling"), "Upgrades need points")
	store.complete_run(1000)
	_check(UpgradeRules.choose(GARAGE, store, damas, "handling"), "An affordable level is bought")
	_check(store.wallet == 800, "The first level costs 200")
	_check(UpgradeRules.choose(GARAGE, store, damas, "handling"), "The next level is bought")
	_check(store.wallet == 350, "The second level costs 450")
	_check(not UpgradeRules.choose(GARAGE, store, damas, "handling"), "Level 3 needs 900")
	_check(not UpgradeRules.choose(GARAGE, store, damas, "turbo"), "Unknown upgrades refused")
	var levels := UpgradeRules.levels(GARAGE, store, damas)
	_check(levels == {"handling": 2, "tank": 0, "suspension": 0}, "Levels are per upgrade")
	_check(UpgradeRules.levels(GARAGE, store, matiz).handling == 0, "Levels belong to one car")
	store.complete_run(5000)
	UpgradeRules.choose(GARAGE, store, damas, "handling")
	var wallet := store.wallet
	_check(not UpgradeRules.choose(GARAGE, store, damas, "handling"), "Maxed upgrades refused")
	_check(store.wallet == wallet, "A refused purchase costs nothing")
	var reopened := _store()
	_check(reopened.upgrades == {"damas": {"handling": 3}}, "Upgrades survive relaunch")
	_check(reopened.wallet == wallet, "The wallet after upgrades survives relaunch")
	store.free()
	reopened.free()
	_write(
		(
			'{"version": 1, "stats": {"best_score": 7}, "garage": {"upgrades": {"damas":'
			+ ' {"tank": 2, "handling": -1, "suspension": "x"}, "matiz": 4, "7": {"tank": 99}}}}'
		)
	)
	store = _store()
	_check(store.best_score == 7, "Damaged upgrade fields never lose the record")
	_check(store.upgrades == {"damas": {"tank": 2}, "7": {}}, "Damaged levels fall back")
	store.free()


func _test_effects() -> void:
	var store := LocalProgressStore.new()
	store.upgrades = {"damas": {"handling": 2, "tank": 1, "suspension": 3}}
	var damas := GARAGE.find("damas")
	var boosts := UpgradeRules.boosts(GARAGE, store, damas)
	_check(is_equal_approx(boosts.handling, 1.2), "Handling boost")
	_check(is_equal_approx(boosts.tank, 1.25), "Tank boost")
	_check(is_equal_approx(boosts.suspension, 0.25), "Suspension cut")
	var tuned := UpgradeRules.tuned_settings(damas.settings, boosts)
	_check(tuned != damas.settings, "Upgraded handling uses a copy")
	_check(is_equal_approx(tuned.steering_speed, damas.settings.steering_speed * 1.2), "Faster")
	_check(is_equal_approx(damas.settings.steering_speed, 640.0), "Shared settings never change")
	var empty := LocalProgressStore.new()
	var plain := UpgradeRules.boosts(GARAGE, empty, damas)
	_check(UpgradeRules.tuned_settings(damas.settings, plain) == damas.settings, "No copy needed")
	store.free()
	empty.free()


func _test_garage_buttons() -> void:
	_cleanup()
	_write('{"version": 1, "stats": {"best_score": 0}, "garage": {"wallet": 400}}')
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	var steering := game.world.player.settings.steering_speed
	game.open_garage()
	var picker := game.hud.garage_menu.upgrades
	_check(picker.buttons.size() == 3, "Three upgrade buttons")
	var handling: Button = picker.buttons["handling"]
	_check(handling.text == "Handling\n0/3 · 200", "Buttons show name, level, and price")
	await _click(handling)
	_check(game.progress.wallet == 200, "A real click buys a level")
	_check(handling.text == "Handling\n1/3 · 450", "The button shows the next level")
	_check(handling.disabled, "Unaffordable levels are disabled")
	_check(
		is_equal_approx(game.world.player.settings.steering_speed, steering * 1.1),
		"The road car steers faster at once"
	)
	game.progress.wallet = 5000
	game.choose_upgrade("tank")
	game.choose_upgrade("tank")
	game.choose_upgrade("tank")
	_check(
		(
			(picker.buttons["tank"] as Button).text == "Tank\n3/3 · MAX"
			and (picker.buttons["tank"] as Button).disabled
		),
		"Maxed upgrades say MAX"
	)
	game.choose_car("matiz")
	_check(
		(picker.buttons["handling"] as Button).text == "Handling\n0/3 · 200",
		"Each car has its own levels"
	)
	game.hud.garage_menu.close()
	game.start_run()
	game.world.player.set_physics_process(false)
	var wallet := game.progress.wallet
	game.choose_upgrade("handling")
	_check(game.progress.wallet == wallet, "Upgrades cannot be bought during a drive")
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
	game.progress.upgrades = {"damas": {"handling": 3, "tank": 1}}
	game.progress.wallet = 1234567
	game.choose_car("damas")
	game.open_garage()
	for _frame in range(3):
		await process_frame
	var card := game.hud.garage_menu.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Garage fits: " + locale)
	for button: Button in game.hud.garage_menu.upgrades.buttons.values():
		var font := button.get_theme_font("font")
		var size := button.get_theme_font_size("font_size")
		for line in button.text.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			_check(width <= button.size.x - 8.0, "Upgrade text fits: %s %s" % [locale, line])
	view.free()


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

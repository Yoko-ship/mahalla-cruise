extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://route_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_catalogue()
	_test_unlock_and_save()
	_test_drive()
	await _test_picker()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: city routes, unlocks, points bonus, landmarks, and picker (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_catalogue() -> void:
	var ids: Array[String] = []
	var regions: Array[String] = []
	var last_price := -1
	var last_scale := 0.0
	for route in GARAGE.routes:
		ids.append(route.id)
		regions.append(route.region_code)
		_check(route.price > last_price and route.points_scale > last_scale, "Each city costs more")
		last_price = route.price
		last_scale = route.points_scale
		_check(not tr(route.name_key).is_empty(), "Route has a name")
	_check(ids == ["tashkent", "samarkand", "bukhara", "khiva"], "Four cities in order")
	_check(regions == ["01", "30", "80", "90"], "Real plate region codes")
	_check(GARAGE.routes[0].price == 0 and GARAGE.routes[0].landmarks.is_empty(), "Tashkent free")
	_check(GARAGE.find_route("samarkand").bonus_percent() == 15, "Bonus as a percent")


func _test_unlock_and_save() -> void:
	_cleanup()
	var store := _store()
	var damas := GARAGE.find("damas")
	_check(RouteRules.current(GARAGE, store).id == "tashkent", "Drives start in Tashkent")
	_check(not GarageRules.apply("route", "samarkand", GARAGE, store, damas), "Locked costs 1500")
	_check(not GarageRules.apply("route", "moon", GARAGE, store, damas), "Unknown routes refused")
	store.complete_run(2000)
	_check(GarageRules.apply("route", "samarkand", GARAGE, store, damas), "Unlocking spends points")
	_check(store.wallet == 500 and store.route == "samarkand", "Unlocked and chosen")
	_check(GarageRules.apply("route", "tashkent", GARAGE, store, damas), "Owned cities switch free")
	_check(store.wallet == 500 and store.route == "tashkent", "No charge to switch")
	GarageRules.apply("route", "samarkand", GARAGE, store, damas)
	var view := GarageRules.view(GARAGE, store, damas)
	var offer: Dictionary = view.plate_offers[0]
	_check(String(offer.plate).begins_with("30"), "Plate auction follows the city")
	var reopened := _store()
	_check(reopened.owned_routes == ["tashkent", "samarkand"], "Unlocks survive relaunch")
	_check(reopened.route == "samarkand", "The chosen city survives relaunch")
	store.free()
	reopened.free()
	_write('{"version": 1, "stats": {"best_score": 2}, "garage": {"route": "khiva"}}')
	store = _store()
	_check(store.route == "tashkent", "A city that is not owned falls back")
	store.owned_routes.append("atlantis")
	store.route = "atlantis"
	_check(RouteRules.current(GARAGE, store).id == "tashkent", "Unknown saved city drives Tashkent")
	store.free()


func _test_drive() -> void:
	var game := _game("")
	game.progress.wallet = 10000
	game.garage_action("route", "bukhara")
	var world := game.world
	_check(world.scenery.modulate == GARAGE.find_route("bukhara").tint, "The street is tinted")
	_check(world.landmarks.kind == "kalyan" and world.landmarks.visible, "Bukhara landmarks")
	game.start_run()
	game.world.player.set_physics_process(false)
	var note := MONEY_SCENE.instantiate() as MoneyPickup
	note.position = world.player.position - Vector2(0, 40)
	world.pickups.add_child(note)
	var definition := game.pickup_settings.select_note(false, 0.0)
	note.configure(definition, 10, game.pickup_settings.collision_half_size)
	world.pickups.items.append(note)
	game.advance(0.1)
	_check(game.score == 13, "Bukhara pays 30% more (10 → 13)")
	var before := world.landmarks.scroll_offset
	game.advance(0.1)
	_check(world.landmarks.scroll_offset != before, "Landmarks scroll with the road")
	world.traffic.contacted.emit()
	game.garage_action("route", "tashkent")
	_check(game.progress.route == "bukhara", "The city cannot change on the results screen")
	game.open_garage()
	game.hud.garage_menu.close()
	game.garage_action("route", "tashkent")
	_check(not world.landmarks.visible and world.scenery.modulate == Color.WHITE, "Back home")
	game.free()


func _test_picker() -> void:
	_cleanup()
	var game := _game(_path)
	var picker := game.hud.menu.route_picker
	var play := game.hud.menu.primary_button
	_check(picker.shown_route().id == "tashkent" and not play.disabled, "Tashkent is ready")
	await _click(picker.next_button)
	_check(picker.shown_route().id == "samarkand" and picker.is_locked(), "Browsing a locked city")
	_check(picker.choice_button.text == "Samarkand\nUnlock · 1500", "The price is shown")
	_check(play.disabled and picker.choice_button.disabled, "Play waits; no points to unlock")
	_check(game.progress.route == "tashkent", "Browsing does not change the city")
	game.progress.wallet = 1600
	game.garage_action("car", "damas")
	_check(picker.shown_route().id == "samarkand", "A refresh keeps the browsed city")
	await _click(picker.choice_button)
	_check(game.progress.route == "samarkand" and game.progress.wallet == 100, "A click unlocks")
	_check(not play.disabled, "Play is ready for the unlocked city")
	_check(picker.choice_button.text == "Samarkand\n+15% points", "The bonus is shown")
	await _click(picker.previous_button)
	_check(game.progress.route == "tashkent", "Browsing to an owned city chooses it")
	await _click(picker.previous_button)
	_check(picker.shown_route().id == "khiva" and play.disabled, "The arrows wrap around")
	await _click(play)
	_check(game.state == CruiseGame.RunState.START, "A locked city cannot be played")
	await _click(picker.next_button)
	await _click(play)
	_check(game.state == CruiseGame.RunState.PLAYING, "Play starts the chosen city")
	game.pause_run()
	_check(not picker.visible and not play.disabled, "Pause hides the picker; Resume works")
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
	game.garage_action("car", "damas")
	var picker := game.hud.menu.route_picker
	for route in GARAGE.routes:
		for _frame in range(2):
			await process_frame
		var card := game.hud.menu.get_node("Center/Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Start fits: " + locale)
		var button := picker.choice_button
		var font := button.get_theme_font("font")
		var size := button.get_theme_font_size("font_size")
		for line in button.text.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			_check(width <= button.size.x - 8.0, "%s fits: %s" % [line, locale])
		picker._browse(1)
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

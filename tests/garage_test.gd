extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://garage_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	await _test_default_roster()
	await _test_purchase_flow()
	_test_hidden_saved_car()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_check(GARAGE.available().size() == 4, "Tests never remove artwork from the shared roster")
	_check(is_equal_approx(GARAGE.cars[1].settings.steering_speed, 780.0), "Car tuning unchanged")
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: garage menu, car stats in play, purchases, and layouts (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_default_roster() -> void:
	_cleanup()
	var game := _new_game(null)
	_check(game.car.id == "damas", "The game starts with the Damas")
	_check(game.hud.menu.garage_button.visible, "The start screen offers the garage")
	await _click(game.hud.menu.garage_button)
	_check(game.hud.garage_menu.visible and not game.hud.menu.visible, "Garage opens from start")
	_check(game.hud.garage_menu.rows.get_child_count() == 4, "All four illustrated cars are listed")
	_check(not game.hud.garage_menu.note.visible, "No coming-soon note for a complete roster")
	_check(game.hud.garage_menu.row_for("matiz").action.disabled, "An empty wallet cannot buy cars")
	var row := game.hud.garage_menu.row_for("damas")
	_check(row.action.disabled and row.action.text == "Selected", "The driven car is marked")
	_check(game.hud.garage_menu.wallet_label.text == "Wallet: 0 pts", "The wallet is shown")
	await _click(game.hud.garage_menu.back_button)
	_check(not game.hud.garage_menu.visible and game.hud.menu.visible, "Back returns to start")
	game.start_run()
	game.player.set_physics_process(false)
	game.hud.menu.show_pause(0, 0.0)
	_check(not game.hud.menu.garage_button.visible, "The garage is not offered while paused")
	game.free()


func _test_purchase_flow() -> void:
	_cleanup()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string('{"version": 1, "stats": {"best_score": 0}, "garage": {"wallet": 400}}')
	file.close()
	var game := _new_game(null)
	game.open_garage()
	var menu := game.hud.garage_menu
	_check(
		menu.rows.get_child_count() == 4 and not menu.note.visible, "Illustrated cars are listed"
	)
	_check(not menu.row_for("matiz").action.disabled, "Affordable cars can be bought")
	_check(menu.row_for("cobalt").action.disabled, "Expensive cars wait for more points")
	_check(menu.row_for("gentra").action.text == "Buy\n2500 pts", "Prices are shown on the action")
	await _click(menu.row_for("matiz").action)
	_check(game.progress.wallet == 100 and game.car.id == "matiz", "A real click buys the Matiz")
	var matiz := game.garage.find("matiz")
	_check(game.player.settings == matiz.settings, "The Matiz handling drives the player")
	_check(
		game.player.collision_bounds().size == matiz.settings.collision_half_size * 2.0,
		"The Matiz uses its smaller collision size"
	)
	_check(game.player.visual.sprite.texture == matiz.texture, "The road car shows the Matiz")
	_check(game.hud.menu.car.texture == matiz.texture, "The start screen shows the chosen car")
	_check(menu.row_for("matiz").action.text == "Selected", "The garage marks the new car")
	_check(menu.row_for("damas").action.text == "Select", "Owned cars can be chosen again")
	_check(menu.wallet_label.text == "Wallet: 100 pts", "The wallet updates after buying")
	game.choose_car("cobalt")
	_check(game.progress.wallet == 100 and game.car.id == "matiz", "Unaffordable buys are refused")
	menu.close()
	game.start_run()
	game.player.set_physics_process(false)
	game.choose_car("damas")
	_check(game.car.id == "matiz", "Cars cannot change during a drive")
	game.advance(1.0)
	var expected := game.road_settings.scroll_speed * 0.95 / game.road_settings.pixels_per_metre
	_check(is_equal_approx(game.distance_metres, expected), "The Matiz travels at its own speed")
	game.score = 40
	# Streak payouts are covered by streak_test; keep this wallet about run points only.
	game.daily.state.streak_paid = true
	_crash(game)
	_check(game.progress.wallet == 140, "Finishing a drive pays into the wallet")
	_check(
		game.hud.game_over_panel.wallet_result.text == "Wallet +40 · 140 pts",
		"Results show the earnings"
	)
	await _click(game.hud.game_over_panel.garage_button)
	_check(game.state == CruiseGame.RunState.START, "Results can return to the garage")
	_check(game.distance_metres == 0.0 and game.score == 0, "Leaving results resets the run")
	_check(game.traffic.vehicles.is_empty(), "Leaving results clears traffic")
	_check(menu.visible and not game.hud.game_over_panel.visible, "The garage replaces results")
	_check(not game.player.visible, "The road car waits for Play")
	game.choose_car("damas")
	_check(game.car.id == "damas" and game.progress.wallet == 140, "Switching owned cars is free")
	await _click(menu.back_button)
	await _click(game.hud.menu.primary_button)
	_check(game.state == CruiseGame.RunState.PLAYING, "Play starts after visiting the garage")
	game.free()
	var reopened := _new_game(null)
	_check(reopened.car.id == "damas", "The chosen car is restored after relaunch")
	_check(
		reopened.progress.owned_cars == ["damas", "matiz"], "Purchases are restored after relaunch"
	)
	reopened.free()


func _test_hidden_saved_car() -> void:
	_cleanup()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(
		(
			'{"version": 1, "stats": {"best_score": 0}, "garage": {"owned": ["damas", "gentra"],'
			+ ' "selected": "gentra"}}'
		)
	)
	file.close()
	var game := _new_game(_without_art("gentra"))
	_check(game.car.id == "damas", "A saved car without artwork falls back to the Damas")
	game.open_garage()
	_check(game.hud.garage_menu.row_for("gentra") == null, "Cars without artwork stay hidden")
	_check(game.hud.garage_menu.note.visible, "Players learn that more cars are coming")
	_check(game.progress.selected_car == "gentra", "The fallback keeps the saved choice")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
	_check(saved.garage.selected == "gentra", "The fallback does not overwrite the saved car")
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
	var owned: Array[String] = ["damas", "matiz"]
	game.progress.owned_cars.assign(owned)
	game.progress.wallet = ProgressData.MAX_SCORE
	game.choose_car("matiz")
	game.open_garage()
	await _settle()
	var card := game.hud.garage_menu.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Garage fits: " + locale)
	for row: GarageRow in game.hud.garage_menu.rows.get_children():
		_check(row.action.size.y >= 48, "Car actions are touch-sized: " + locale)
		_check(
			row.get_global_rect().encloses(row.action.get_global_rect()),
			"Action text fits its row: %s %s" % [locale, row.car.id]
		)
		var font := row.action.get_theme_font("font")
		var font_size := row.action.get_theme_font_size("font_size")
		for line in row.action.text.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_check(width <= row.action.size.x - 4.0, "Action label is readable: " + locale)
	view.free()


func _new_game(catalogue: GarageCatalogue) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	if catalogue != null:
		game.garage = catalogue
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	return game


func _without_art(id: String) -> GarageCatalogue:
	# A copy where one car lacks artwork, as when a new car is added before its sprite.
	var catalogue := GARAGE.duplicate() as GarageCatalogue
	var cars: Array[CarDefinition] = []
	for car in GARAGE.cars:
		var copy := car.duplicate() as CarDefinition
		if copy.id == id:
			copy.texture = null
		cars.append(copy)
	catalogue.cars = cars
	return catalogue


func _crash(game: CruiseGame) -> void:
	var settings := game.traffic_settings.duplicate() as TrafficSettings
	settings.first_spawn_distance = 1.0
	game.traffic.configure(game.road_settings, settings)
	game.traffic.advance(1.0, game.player.collision_bounds())
	var car: TrafficCar = game.traffic.vehicles.front()
	car.position = game.player.position - Vector2(0, 90)
	game.advance(0.5)


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


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

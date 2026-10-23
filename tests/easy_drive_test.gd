extends SceneTree

const MAIN: PackedScene = preload("res://src/main.tscn")
const CAR: PackedScene = preload("res://src/traffic/traffic_car.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_and_bumps()
	_test_finish_and_modes()
	_test_long_drive()
	await _test_layouts()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: Easy default, forgiving bumps, simple HUD, finishing and Challenge (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _game() -> CruiseGame:
	var game := MAIN.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.set_language("en")
	game.world.player.set_physics_process(false)
	return game


func _bump(game: CruiseGame) -> void:
	var car := CAR.instantiate() as TrafficCar
	car.position = game.world.player.position - Vector2(0, 70)
	game.world.traffic.add_child(car)
	car.configure(Vector2(20, 36), Color.WHITE)
	game.world.traffic.vehicles.append(car)
	game.advance(0.01)
	_check(car not in game.world.traffic.vehicles, "Touched car leaves the player's path")


func _test_default_and_bumps() -> void:
	var game := _game()
	_check(game.easy_mode and game.world.easy_settings != null, "New launches default to Easy")
	_check(game.hud.menu.mode_button.text == "Easy drive ↔", "Menu identifies the selected mode")
	_check(not game.hud.menu.gift_button.visible, "Easy menu does not prompt wheel spins")
	var traffic := game.world.traffic._settings
	_check(traffic != game.traffic_settings, "Easy tuning belongs to this run")
	_check(traffic.models == game.traffic_settings.models, "Realistic traffic art is preserved")
	_check(traffic.max_vehicles == 2 and traffic.minimum_spawn_scale == 1, "Traffic stays gentle")
	_check(not traffic.sheep_enabled, "Crossing flocks are disabled in Easy")
	_check(game.traffic_settings.max_vehicles == 3, "Challenge settings remain unchanged")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.advance(4.0)
	_check(game.world.traffic.vehicles.is_empty(), "Opening stretch gives time to learn steering")
	_check(game.world.travel_pixels(1.0) == 180.0, "Easy speed is capped")
	_check(game.hud.drive.pause_button.visible, "Pause remains accessible")
	_check(game.hud.drive.score_label.visible, "Collected points remain visible")
	for control: Control in [
		game.hud.drive.fuel_gauge,
		game.hud.drive.speedometer,
		game.hud.drive.brake_pedal,
		game.hud.drive.ride_chip,
		game.hud.drive.best_label
	]:
		_check(not control.visible, "Advanced dashboard controls stay hidden")
	game.score = 123
	_bump(game)
	_check(game.state == CruiseGame.RunState.PLAYING, "A real collision does not end Easy play")
	_check(game.score == 123, "A bump does not take earned points")
	_check(game.world.bump_remaining > 0.0, "Contact starts a brief slowdown")
	var seconds := game.world.bump_remaining
	game.pause_run()
	game.advance(5.0)
	_check(game.world.bump_remaining == seconds, "Pause freezes bump recovery")
	game.resume_run()
	game.world.player.set_physics_process(false)
	var slowed := game.world.travel_pixels(0.1) / 0.1
	_check(slowed < 180.0 and slowed > 0.0, "Bump slows travel without stopping it")
	seconds = game.world.bump_remaining
	_bump(game)
	_check(game.world.bump_remaining < seconds, "Repeated contact cannot restart the slowdown")
	game.world.travel_pixels(3.0)
	_check(game.world.travel_pixels(1.0) == 180.0, "Full speed returns automatically")
	game.world.fuel.ran_out.emit()
	_check(game.state == CruiseGame.RunState.PLAYING, "Fuel cannot end an Easy drive")
	game.free()


func _test_finish_and_modes() -> void:
	var game := _game()
	game.progress.owned_cars.append("malibu")
	game.garage_action("car", "malibu")
	_check(game.world.travel_pixels(1.0) <= 180.0, "Fast garage cars respect Easy's speed cap")
	game.hud.menu.mode_button.pressed.emit()
	_check(not game.easy_mode and game.world.easy_settings == null, "Menu selects Challenge")
	_check(game.world.traffic._settings == game.traffic_settings, "Original traffic rules return")
	_check(game.hud.menu.gift_button.visible, "Challenge menu restores existing activities")
	game.hud.menu.mode_button.pressed.emit()
	_check(game.easy_mode and game.world.pickups.simple_mode, "Switching back restores Easy")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.set_easy_mode(false)
	_check(game.easy_mode, "Difficulty cannot change during an active run")
	game.finish_drive()
	_check(game.state == CruiseGame.RunState.PLAYING, "Finishing requires the pause screen")
	game._add_points(25)
	game.distance_metres = 125.0
	game.pause_run()
	_check(game.hud.menu.finish_button.visible, "Pause offers Finish drive")
	game.hud.menu.finish_button.pressed.emit()
	_check(game.is_game_over and not game.hud.menu.visible, "Finish replaces pause with results")
	_check(
		game.hud.game_over_panel.title_label.text == "Nice drive!", "Results celebrate the drive"
	)
	_check(game.progress.wallet >= 25, "Finishing banks collected points")
	var wallet := game.progress.wallet
	game.hud.menu.finish_button.pressed.emit()
	_check(game.progress.wallet == wallet, "Repeated finish events cannot pay twice")
	_check(not game.hud.game_over_panel.share_button.visible, "Easy results keep focus inside game")
	game.restart_run()
	_check(game.state == CruiseGame.RunState.PLAYING, "Play again starts a new Easy drive")
	_check(game.world.bump_remaining == 0 and game.distance_metres == 0, "Restart clears run state")
	_check(game.world.journey.index == 0, "Restart resets the six-location journey")
	game.free()


func _test_long_drive() -> void:
	var game := _game()
	game.start_run()
	game.world.player.set_physics_process(false)
	for step in 1500:
		game.advance(0.25)
	_check(game.state == CruiseGame.RunState.PLAYING, "Several minutes of Easy play stay forgiving")
	_check(game.distance_metres > 3000, "Easy mode still visits all six locations")
	_check(game.world.traffic.vehicles.size() <= 2, "Long drives retain the two-car cap")
	_check(game.world.traffic.sheep_crossing.flock.is_empty(), "Long drives spawn no flocks")
	_check(game.world.hazards.item_bounds().is_empty(), "No road works or potholes appear")
	_check(game.world.fuel.stations.is_empty(), "No refuelling task appears")
	_check(game.world.pickups.bus_stops.is_empty(), "No bus-stop task appears")
	_check(game.world.pickups.power_ups.is_empty(), "No extra power-up rules are introduced")
	_check(
		not game.world.taxi.is_busy() and not game.world.police.is_busy(), "No timed jobs or fines"
	)
	_check(game.world.weather.kind == "clear", "Easy driving stays clearly visible")
	_check(game.world.pickups.items.size() > 0, "Collectibles still appear")
	game.free()


func _test_layouts() -> void:
	var game := _game()
	for locale in ["en", "uz", "ru"]:
		game.set_language(locale)
		for easy: bool in [true, false]:
			game.set_easy_mode(easy)
			await process_frame
			var card := game.hud.menu.get_node("Center/Card") as Control
			_check(
				card.size.y <= 768,
				"Start menu fits: %s easy=%s height=%s" % [locale, easy, card.size.y]
			)
			_check(game.hud.menu.mode_button.size.y >= 48, "Mode selector has a large touch target")
			_check(game.hud.menu.primary_button.size.y >= 56, "Play remains easy to tap")
	game.set_easy_mode(true)
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(game.hud.drive.steering_guide.visible, "First drive demonstrates the finger gesture")
	var location := game.hud.drive.pause_button.position
	game.hud.set_playfield_offset(game.position + Vector2(0, 72))
	_check(
		game.hud.drive.pause_button.position == location + Vector2(0, 72),
		"Easy HUD follows tall view"
	)
	game.pause_run()
	game.set_language("ru")
	_check(game.hud.menu.finish_button.text == "Завершить поездку", "Finish action is localized")
	_check(not game.hud.drive.steering_guide.visible, "Gesture guide hides during pause")
	game.resume_run()
	game.advance(7.0)
	_check(not game.hud.drive.steering_guide.visible, "Gesture guide expires after onboarding")
	game.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const REVIVAL: RevivalSettings = preload("res://src/revival/default_revival.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_no_offer()
	await _test_accept()
	_test_decline_and_timeout()
	_test_out_of_fuel()
	await _test_layout()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: second chance offer, payment, revive, once per drive, and layout (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_no_offer() -> void:
	var early := _new_game(1000)
	_drive(early, REVIVAL.min_metres - 20.0)
	_crash(early)
	_check(early.is_game_over, "A short drive goes straight to the results")
	_check(not early.hud.second_chance.visible, "No second chance before 300 m")
	early.free()
	var poor := _new_game(REVIVAL.price - 1)
	_drive(poor, REVIVAL.min_metres + 10.0)
	_crash(poor)
	_check(poor.is_game_over and not poor.hud.second_chance.visible, "Not offered without money")
	poor.free()
	_check(REVIVAL.price_for(0) == 150 and REVIVAL.price_for(1000) == 400, "Long drives cost more")
	var rich_drive := _new_game(399)
	_drive(rich_drive, REVIVAL.min_metres + 10.0)
	rich_drive.score = 1000
	_crash(rich_drive)
	_check(rich_drive.is_game_over, "399 cannot continue a 1,000-point drive")
	rich_drive.free()


func _test_accept() -> void:
	var game := _new_game(500)
	_drive(game, REVIVAL.min_metres + 10.0)
	game.score = 40
	_crash(game)
	var card := game.hud.second_chance
	_check(game.state == CruiseGame.RunState.SECOND_CHANCE, "A long drive offers a second chance")
	_check(card.visible and not game.hud.game_over_panel.visible, "The card shows before results")
	_check(card.title.text == "One more chance?", "The card asks")
	_check(
		card.message.text == "Pay 160 points from your wallet and drive on.",
		"Price: 150 + 25% of 40"
	)
	_check(card.wallet_label.text == "Wallet: 500 points", "Wallet shown")
	_check(card.accept_button.text == "Drive on · 160", "The button names the price")
	var metres := game.distance_metres
	game.advance(1.0)
	_check(is_equal_approx(game.distance_metres, metres), "The road waits for the answer")
	game.restart_run()
	game.pause_run()
	_check(game.state == CruiseGame.RunState.SECOND_CHANCE, "Restart and pause wait too")
	_check(game.achievements.state.stats.get("runs", 0) == 0, "Nothing is booked while deciding")
	await process_frame
	await process_frame
	await _click(card.accept_button)
	_check(game.state == CruiseGame.RunState.PLAYING, "Paying drives on")
	_check(game.progress.wallet == 340, "The price leaves the wallet")
	_check(not card.visible and game.hud.drive.visible, "The road is back")
	_check(game.score == 40 and game.distance_metres == metres, "The same drive continues")
	_check(game.hud.drive.pickup_label.text == "Back on the road! Careful", "Drivers are warned")
	_check(game.world.player.is_physics_processing(), "Steering works again")
	game.world.player.set_physics_process(false)
	_check(game.world.pickups.effects.grace_metres == REVIVAL.grace_metres, "A short grace follows")
	_check(
		game.world.traffic.vehicles.all(
			func(car: TrafficCar) -> bool: return not car.has_contacted
		),
		"The crashed car is gone"
	)
	game.world.traffic.contacted.emit()
	_check(not game.is_game_over, "Contact during the grace is absorbed")
	_drive(game, REVIVAL.grace_metres + 5.0)
	_check(game.distance_metres > metres + REVIVAL.grace_metres, "The drive goes on")
	_crash(game)
	_check(game.is_game_over and not card.visible, "Only one second chance per drive")
	_check(game.achievements.state.stats.get("runs", 0) == 1, "The drive is booked once")
	# Daily tasks and rivals may add their own rewards on top of the score.
	var paid := game.progress.wallet - 340
	_check(paid >= game.score and paid < game.score * 2, "The drive pays into the wallet once")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_drive(game, REVIVAL.min_metres + 10.0)
	_crash(game)
	_check(card.visible, "A new drive can be offered again")
	game.free()


func _test_decline_and_timeout() -> void:
	var game := _new_game(500)
	_drive(game, REVIVAL.min_metres + 10.0)
	_crash(game)
	game.hud.second_chance.decline_button.pressed.emit()
	_check(game.is_game_over and game.hud.game_over_panel.visible, "Declining shows the results")
	_check(game.progress.wallet >= 500 + game.score, "Declining costs nothing")
	_check(game.achievements.state.stats.get("runs", 0) == 1, "Declining books the drive")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_drive(game, REVIVAL.min_metres + 10.0)
	_crash(game)
	var card := game.hud.second_chance
	card._process(REVIVAL.decide_seconds * 0.5)
	_check(card.visible and card.timer_bar.value < 0.6, "The bar counts down")
	card._process(REVIVAL.decide_seconds)
	_check(game.is_game_over and not card.visible, "Waiting too long declines")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_drive(game, REVIVAL.min_metres + 10.0)
	_crash(game)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game.hud._unhandled_key_input(escape)
	_check(game.is_game_over and not card.visible, "Back declines")
	game.free()


func _test_out_of_fuel() -> void:
	var game := _new_game(500)
	var fuel := game.world.fuel
	_drive(game, REVIVAL.min_metres + 10.0)
	fuel.fuel_metres = 0.5
	_drive(game, 2.0)
	_check(game.state == CruiseGame.RunState.SECOND_CHANCE, "An empty tank offers it too")
	game.choose_second_chance(true)
	_check(game.state == CruiseGame.RunState.PLAYING, "Paying refuels and drives on")
	_check(is_equal_approx(fuel.share(), REVIVAL.refuel_share), "Some methane is added")
	_drive(game, 20.0)
	_check(not game.is_game_over and fuel.share() < REVIVAL.refuel_share, "The tank drains again")
	game.free()


func _test_layout() -> void:
	for locale in ProgressData.LANGUAGES:
		var view := SubViewport.new()
		view.size = Vector2i(432, 768)
		root.add_child(view)
		var game := MAIN_SCENE.instantiate() as CruiseGame
		game.easy_mode = false  # Exercise the original Challenge rules.
		(game.get_node("Progress") as LocalProgressStore).save_path = ""
		view.add_child(game)
		game.set_process(false)
		game.set_language(locale)
		game.hud.offer_second_chance(ProgressData.MAX_SCORE, ProgressData.MAX_SCORE, 5.0)
		for _frame in range(3):
			await process_frame
		var card := game.hud.second_chance.get_node("Center/Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Card fits: " + locale)
		_check(game.hud.second_chance.accept_button.size.y >= 48, "Touch target: " + locale)
		_check(not game.hud.second_chance.title.text.contains("revive"), "Translated: " + locale)
		view.free()


func _new_game(wallet: int) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 1.0e9
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0e9
	var traffic := game.get_node("World/Traffic") as TrafficController
	traffic.sheep_settings = traffic.sheep_settings.duplicate() as SheepSettings
	traffic.sheep_settings.first_crossing_metres = 1.0e9
	# A shield power-up would absorb the test crashes.
	var pickups := game.get_node("World/Pickups") as PickupController
	pickups.power_up_settings = pickups.power_up_settings.duplicate() as PowerUpSettings
	pickups.power_up_settings.first_spawn_metres = 1.0e9
	pickups.passenger_settings = pickups.passenger_settings.duplicate() as PassengerSettings
	pickups.passenger_settings.first_stop_metres = 1.0e9
	var taxi := game.get_node("World/Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.first_station_metres = 1.0e9
	var cameras := game.get_node("World/Cameras") as SpeedCameraController
	cameras.settings = cameras.settings.duplicate() as SpeedCameraSettings
	cameras.settings.first_metres = 1.0e9
	var police := game.get_node("World/Police") as PoliceController
	police.settings = police.settings.duplicate() as PoliceSettings
	police.settings.first_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.progress.wallet = wallet
	game.daily.state.streak_paid = true
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


## A car appears level with the player and hits it.
func _crash(game: CruiseGame) -> void:
	var car := preload("res://src/traffic/traffic_car.tscn").instantiate() as TrafficCar
	car.position = game.world.player.position - Vector2(0, 80)
	game.world.traffic.add_child(car)
	car.configure(game.traffic_settings.collision_half_size, Color.WHITE)
	game.world.traffic.vehicles.append(car)
	for _frame in range(30):
		game.advance(STEP)
		if game.state != CruiseGame.RunState.PLAYING:
			return


func _drive(game: CruiseGame, metres: float) -> void:
	var start := game.distance_metres
	var frames := 0
	while game.distance_metres - start < metres and frames < 100000:
		game.advance(STEP)
		frames += 1
		if game.state != CruiseGame.RunState.PLAYING:
			return


func _click(button: Button) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = button.get_global_rect().get_center()
	press.pressed = true
	root.push_input(press, true)
	press.pressed = false
	root.push_input(press, true)
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const MAIN: PackedScene = preload("res://src/main.tscn")
const MONEY: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const CAR: PackedScene = preload("res://src/traffic/traffic_car.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_collection_and_recovery()
	_test_modes_and_tuning()
	await _test_locales_and_layout()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: collection targets, bonuses, pause, restart and layouts (%d checks)" % checks)
	quit(1 if failures else 0)


func _game(easy: bool = true, tuning: EasyDriveSettings = null) -> CruiseGame:
	var game := MAIN.instantiate() as CruiseGame
	game.easy_mode = easy
	if tuning != null:
		game.easy_settings = tuning
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.set_language("en")
	game.start_run()
	game.world.player.set_physics_process(false)
	return game


func _collect(game: CruiseGame, dollar: bool = false) -> void:
	var settings := game.pickup_settings
	var note := settings.dollar_note if dollar else settings.som_notes[0]
	var item := MONEY.instantiate() as MoneyPickup
	item.position = game.world.player.position - Vector2(0, 20)
	game.world.pickups.add_child(item)
	item.configure(note, settings.points_for(note), settings.collision_half_size)
	game.world.pickups.items.append(item)
	var before := game.som_collected + game.dollars_collected
	game.advance(0.01)
	_check(game.som_collected + game.dollars_collected == before + 1, "Real pickup counts once")


func _test_collection_and_recovery() -> void:
	var game := _game()
	var goal := game.hud.drive.collection_goal
	_check(goal.visible and goal.counter.text == "0/5", "Easy opens with a visible target")
	game._add_points(3)
	_check(goal.collected == 0, "Other score awards do not advance the collection target")
	for index in 4:
		_collect(game)
	_check(goal.counter.text == "4/5" and game.score == 7, "Four notes have no target bonus")
	var car := CAR.instantiate() as TrafficCar
	car.position = game.world.player.position - Vector2(0, 70)
	game.world.traffic.add_child(car)
	car.configure(Vector2(20, 36), Color.WHITE)
	game.world.traffic.vehicles.append(car)
	game.advance(0.01)
	_check(game.world.bump_remaining > 0, "A real traffic collision occurred")
	_check(goal.collected == 4 and game.score == 7, "Bumps preserve target progress and points")
	_collect(game, true)
	_check(game.score == 32, "Fifth note pays its dollar value plus exactly 15 bonus points")
	_check(game.som_collected == 4 and game.dollars_collected == 1, "Bonus adds no fake notes")
	_check(
		goal.counter.text == "+15" and goal.bar.value == 5, "Completion shows full bar and bonus"
	)
	_check(goal.collected == 0, "Next target begins immediately")
	var seconds := goal.success_remaining
	game.pause_run()
	game.advance(8.0)
	game.world.money_collected.emit(1, game.pickup_settings.som_notes[0])
	_check(goal.success_remaining == seconds, "Pause freezes success feedback")
	_check(game.score == 32 and goal.collected == 0, "Late paused events cannot award progress")
	_check(not goal.visible, "Target hides behind pause menu")
	game.resume_run()
	game.world.player.set_physics_process(false)
	_collect(game)
	_check(game.score == 33 and goal.collected == 1, "Next pickup counts during success feedback")
	_check(goal.counter.text == "+15", "Success feedback lasts for its configured duration")
	game.hud.set_distance(game.distance_metres, 2.1)
	_check(goal.counter.text == "1/5" and goal.bar.value == 1, "Current progress follows success")
	for index in 4:
		_collect(game)
	_check(game.score == 52 and goal.collected == 0, "Second group earns one more bonus")
	game.pause_run()
	game.finish_drive()
	_check(game.progress.wallet >= 52, "Finished run banks collection bonuses")
	var wallet := game.progress.wallet
	game.finish_drive()
	_check(game.progress.wallet == wallet, "Repeated finish cannot bank the bonus twice")
	game.restart_run()
	_check(goal.counter.text == "0/5" and game.score == 0, "Restart clears target and score")
	_check(goal.success_remaining == 0, "Restart clears previous completion feedback")
	game.free()


func _test_modes_and_tuning() -> void:
	var game := _game(false)
	for index in 5:
		_collect(game)
	_check(game.score == 5, "Challenge keeps original note scoring")
	_check(not game.hud.drive.collection_goal.visible, "Challenge hides Easy collection target")
	game.free()
	var settings := EasyDriveSettings.new()
	settings.collection_target = 3
	settings.collection_bonus = 7
	game = _game(true, settings)
	for index in 3:
		_collect(game)
	_check(game.score == 10, "Goal and bonus follow typed tuning")
	_check(
		settings.collection_target == 3 and settings.collection_bonus == 7, "Tuning is immutable"
	)
	game.free()


func _test_locales_and_layout() -> void:
	var game := _game()
	var goal := game.hud.drive.collection_goal
	for locale in ["en", "uz", "ru"]:
		game.set_language(locale)
		await process_frame
		_check(not goal.heading.text.contains("collection_"), "Target is translated: " + locale)
		_check(goal.size.x <= 240, "Localized target fits its panel: " + locale)
		_check(
			goal.get_global_rect().encloses(goal.counter.get_global_rect()),
			"Counter fits inside target: " + locale
		)
		_check(
			not goal.get_global_rect().intersects(game.hud.drive.location_banner.get_global_rect()),
			"Location banner stays below target: " + locale
		)
	var position := goal.position
	game.hud.set_playfield_offset(game.position + Vector2(0, 72))
	_check(goal.position == position + Vector2(0, 72), "Target follows tall viewport offset")
	game.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

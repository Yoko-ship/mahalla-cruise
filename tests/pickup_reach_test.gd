extends SceneTree

const MAIN: PackedScene = preload("res://src/main.tscn")
const CAR: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const POWER: PackedScene = preload("res://src/pickups/power_up.tscn")
const DEFAULTS: PickupSettings = preload("res://src/pickups/default_pickups.tres")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reach()
	_test_timing_and_reset()
	_test_traffic_and_power_ups()
	_test_mode_switching()
	_test_roster_reach()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: forgiving money reach, bounds, timing and mode isolation (%d checks)" % checks)
	quit(1 if failures else 0)


func _game(easy: bool = true, start: bool = true) -> CruiseGame:
	var game := MAIN.instantiate() as CruiseGame
	game.easy_mode = easy
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0e6
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	if start:
		game.start_run()
	game.world.player.set_physics_process(false)
	return game


func _note(game: CruiseGame, offset: Vector2) -> MoneyPickup:
	game.world.pickups.drop_note(game.world.player.position + offset, 1000)
	return game.world.pickups.items.back()


func _test_reach() -> void:
	for easy: bool in [true, false]:
		for side: float in [-1.0, 1.0]:
			var game := _game(easy)
			var bounds := game.world.player.collision_bounds()
			var close_note := _note(game, Vector2(side * 44, 0))
			_check(not bounds.intersects(close_note.collection_bounds()), "Close note misses body")
			game.advance(0.01)
			_check(
				game.som_collected == int(easy), "Close pass collects only in Easy on either side"
			)
			_check(game.score == int(easy), "Assisted pickup pays normal value")
			_check(
				game.world.player.collision_bounds() == bounds, "Vehicle collision stays unchanged"
			)
			game.advance(0.01)
			_check(game.score == int(easy), "Collected note cannot pay twice")
			game.free()
	var game := _game()
	for offset: Vector2 in [Vector2(-46, 0), Vector2(46, 0), Vector2(0, -60), Vector2(0, 60)]:
		_note(game, offset)
	game.advance(0.01)
	_check(game.som_collected == 0, "Outside sideways reach and vertical gaps remain misses")
	_check(game.world.pickups.items.size() == 4, "Uncollected notes remain on road")
	game.free()
	game = _game()
	var lane_width := (game.road_settings.right_edge - game.road_settings.left_edge) * 0.25
	_note(game, Vector2(lane_width, 0))
	game.advance(0.01)
	_check(game.som_collected == 0, "An adjacent lane still requires steering")
	game.free()


func _test_timing_and_reset() -> void:
	var game := _game()
	var item := _note(game, Vector2(44, -150))
	var position := item.position
	game.pause_run()
	game.advance(2.0)
	_check(game.score == 0 and item.position == position, "Pause freezes assisted pickups")
	game.resume_run()
	game.world.player.set_physics_process(false)
	game.advance(2.0)
	_check(game.som_collected == 1, "Swept close pass collects even during a long frame")
	_check(game.hud.drive.collection_goal.collected == 1, "Assisted pickup advances target")
	game.advance(0.0)
	_check(game.som_collected == 1, "Long frame collects once")
	game.pause_run()
	game.finish_drive()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_note(game, Vector2(-44, 0))
	game.advance(0.01)
	_check(game.som_collected == 1, "Restart clears old progress and retains Easy reach")
	_check(DEFAULTS.collection_side_margin == 0, "Shared pickup settings stay unchanged")
	_check(
		game.pickup_settings.collection_side_margin == 0, "Main's source settings stay unchanged"
	)
	game.free()


func _test_traffic_and_power_ups() -> void:
	var game := _game()
	var car := CAR.instantiate() as TrafficCar
	car.position = game.world.player.position + Vector2(50, 0)
	game.world.traffic.add_child(car)
	car.configure(Vector2(20, 36), Color.WHITE)
	game.world.traffic.vehicles.append(car)
	_note(game, Vector2(-44, 0))
	var power := POWER.instantiate() as PowerUp
	power.position = game.world.player.position + Vector2(-42, 0)
	game.world.pickups.add_child(power)
	power.configure("magnet", Vector2(16, 16))
	game.world.pickups.power_ups.append(power)
	game.advance(0.01)
	_check(game.som_collected == 1, "Nearby traffic does not prevent a valid pickup")
	_check(game.world.bump_remaining == 0, "Money reach does not enlarge traffic contact")
	_check(not game.world.pickups.effects.magnet_active(), "Money reach does not collect power-ups")
	car.position = game.world.player.position - Vector2(0, 70)
	game.advance(0.01)
	_check(game.world.bump_remaining > 0, "Actual vehicle contact still causes a bump")
	game.free()


func _test_mode_switching() -> void:
	var game := _game(true, false)
	_check(
		game.world.pickups._settings != game.pickup_settings, "Easy uses a private configuration"
	)
	game.set_easy_mode(false)
	_check(
		game.world.pickups._settings == game.pickup_settings, "Challenge restores original tuning"
	)
	game.easy_settings = game.easy_settings.duplicate() as EasyDriveSettings
	game.easy_settings.collection_side_margin = 4.0
	game.set_easy_mode(true)
	game.start_run()
	game.world.player.set_physics_process(false)
	_note(game, Vector2(40, 0))
	_note(game, Vector2(-42, 0))
	game.advance(0.01)
	_check(game.som_collected == 1, "Configured four-pixel margin controls the boundary")
	_check(game.world.pickups.items.size() == 1, "Note outside custom reach stays on road")
	game.free()


func _test_roster_reach() -> void:
	var catalogue := preload("res://src/garage/default_garage.tres") as GarageCatalogue
	for car in catalogue.cars:
		var game := _game(true, false)
		game.progress.owned_cars.append(car.id)
		game.garage_action("car", car.id)
		game.start_run()
		game.world.player.set_physics_process(false)
		var lane_width := (game.road_settings.right_edge - game.road_settings.left_edge) * 0.25
		_note(game, Vector2(lane_width, 0))
		game.advance(0.01)
		_check(game.som_collected == 0, "Next-lane note needs steering in " + car.id)
		var close_x := car.settings.collision_half_size.x + 17.0 + 7.0
		_note(game, Vector2(-close_x, 0))
		game.advance(0.01)
		_check(game.som_collected == 1, "Close pass works in " + car.id)
		game.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

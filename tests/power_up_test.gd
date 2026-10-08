extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const POWER_UP_SCENE: PackedScene = preload("res://src/pickups/power_up.tscn")
const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const SETTINGS: PowerUpSettings = preload("res://src/pickups/default_power_ups.tres")
const SHEEP: SheepSettings = preload("res://src/traffic/default_sheep.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_spawning()
	_test_magnet()
	_test_double_points()
	_test_shield()
	await _test_hud()
	_check(SETTINGS.magnet_metres == 90.0 and SETTINGS.double_metres == 110.0, "Defaults kept")
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: power-up spawning, magnet, double points, shield, and HUD (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_spawning() -> void:
	var game := _new_game(false)
	var pickups := game.world.pickups
	_drive(game, 100.0)
	_check(pickups.power_ups.is_empty(), "No power-ups before 120 m")
	var seen := {}
	var overlaps := 0
	var off_lane := 0
	var crowded := 0
	for _step in range(30000):
		game.advance(1.0 / 30.0)
		for power_up in pickups.power_ups:
			seen[power_up.kind] = true
			off_lane += int(power_up.position.x not in _lanes(game))
			for item in pickups.item_bounds():
				if item.intersects(power_up.collection_bounds()):
					overlaps += 1
		crowded += int(pickups.power_ups.size() > 1)
	_check(seen.size() == 3, "All three kinds appear")
	_check(overlaps == 0, "Power-ups never overlap money")
	_check(off_lane == 0, "Power-ups use money lanes")
	_check(crowded == 0, "At most one power-up on the road")
	game.free()


func _test_magnet() -> void:
	var game := _new_game(true)
	_add_note(game, game.world.player.position + Vector2(90, -120))
	_drive(game, 15.0)
	_check(game.som_collected == 0, "Without a magnet a distant note is missed")
	game.free()
	game = _new_game(true)
	_grab(game, "magnet")
	_check(game.world.pickups.effects.magnet_active(), "Collecting a magnet activates it")
	_check(game.hud.drive.pickup_label.text == "Magnet!", "Magnet feedback is shown")
	_add_note(game, game.world.player.position + Vector2(90, -120))
	_drive(game, 15.0)
	_check(game.som_collected == 1, "The magnet pulls a nearby note in")
	_drive(game, SETTINGS.magnet_metres + 5.0)
	_check(not game.world.pickups.effects.magnet_active(), "The magnet ends after its distance")
	game.pause_run()
	game.free()


func _test_double_points() -> void:
	var game := _new_game(true)
	_grab(game, "double")
	var note := _add_note(game, game.world.player.position + Vector2(0, -60))
	var value := note.points
	_drive(game, 1.0)
	_check(game.score == value * 2, "Double points doubles money")
	_add_car(game, game.world.player.position.x - 46.0, 420.0)
	_drive(game, 40.0)
	_check(game.score == value * 2 + 6, "Double points doubles close calls")
	_drive(game, SETTINGS.double_metres + 5.0)
	_check(game.world.pickups.point_multiplier() == 1, "Double points ends after its distance")
	# Streak payouts are covered by streak_test; keep this wallet about run points only.
	game.daily.state.streak_paid = true
	game.world.traffic.contacted.emit()
	_check(game.progress.wallet == game.score, "Doubled points reach the wallet")
	game.free()


func _test_shield() -> void:
	var game := _new_game(true)
	_grab(game, "shield")
	var car := _add_car(game, game.world.player.position.x, game.world.player.position.y - 90.0)
	game.advance(0.5)
	_check(not game.is_game_over, "The shield absorbs a crash")
	_check(
		not car.is_inside_tree() and game.world.traffic.vehicles.is_empty(),
		"The hit car is cleared"
	)
	_check(game.hud.drive.pickup_label.text == "Shield saved you!", "Shield feedback is shown")
	_check(not game.world.pickups.effects.shield, "The shield is used up")
	_add_car(game, game.world.player.position.x, game.world.player.position.y - 90.0)
	game.advance(0.5)
	_check(not game.is_game_over, "A short grace protects right after the shield breaks")
	_drive(game, SETTINGS.shield_grace_metres + 5.0)
	_add_car(game, game.world.player.position.x, game.world.player.position.y - 90.0)
	game.advance(0.5)
	_check(game.is_game_over, "After the grace the next crash ends the run")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(not game.world.pickups.effects.is_active(), "Restart clears every power-up")
	_check(game.world.pickups.power_ups.is_empty(), "Restart clears road power-ups")
	game.free()
	game = _new_game(true)
	_grab(game, "shield")
	game.world.traffic.sheep_crossing.configure(game.road_settings, SHEEP)
	game.world.traffic.set_distance(300.0)
	game.world.traffic.advance(1.0, Rect2(-5000, -5000, 1, 1))
	var sheep: Sheep = game.world.traffic.sheep_crossing.flock[0]
	sheep.position = game.world.player.position - Vector2(0, 40)
	game.advance(0.2)
	_check(not game.is_game_over and not sheep.is_inside_tree(), "The shield also saves from sheep")
	game.free()


func _test_hud() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language("ru")
	_check(not game.hud.drive.power_up_bar.visible, "Power-up chips are hidden in menus")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(game.hud.drive.power_up_bar.active_kinds().is_empty(), "No chips without power-ups")
	game.world.pickups.effects.activate("magnet")
	game.world.pickups.effects.activate("shield")
	game.advance(0.1)
	_check(game.hud.drive.power_up_bar.visible, "Chips show while driving")
	_check(
		game.hud.drive.power_up_bar.active_kinds() == ["magnet", "shield"], "Active chips listed"
	)
	game.world.pickups.power_up_collected.emit("double")
	_check(game.hud.drive.pickup_label.text == "Двойные очки!", "Power-up feedback is translated")
	await process_frame
	var bar := game.hud.drive.power_up_bar.get_global_rect()
	var pause := game.hud.drive.pause_button.get_global_rect()
	_check(not bar.intersects(pause), "Chips do not cover the Pause button")
	game.pause_run()
	_check(not game.hud.drive.power_up_bar.visible, "Chips hide while paused")
	view.free()


func _new_game(quiet_road: bool) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 1.0e9
	# Sheep are tested elsewhere; here they would end runs of a car that never steers.
	var traffic := game.get_node("World/Traffic") as TrafficController
	traffic.sheep_settings = traffic.sheep_settings.duplicate() as SheepSettings
	traffic.sheep_settings.first_crossing_metres = 1.0e9
	# Fuel is tested elsewhere; a car that never steers would never reach a station.
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	if quiet_road:
		game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
		game.pickup_settings.first_spawn_distance = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	if quiet_road:
		game.world.pickups._metres_until_power_up = 1.0e9
	return game


func _grab(game: CruiseGame, kind: String) -> void:
	var power_up := POWER_UP_SCENE.instantiate() as PowerUp
	power_up.position = game.world.player.position - Vector2(0, 50)
	game.world.pickups.add_child(power_up)
	power_up.configure(kind, SETTINGS.collision_half_size)
	game.world.pickups.power_ups.append(power_up)
	game.advance(0.3)


func _add_note(game: CruiseGame, at: Vector2) -> MoneyPickup:
	var note := MONEY_SCENE.instantiate() as MoneyPickup
	note.position = at
	game.world.pickups.add_child(note)
	var definition := game.pickup_settings.select_note(false, 0.0)
	var points := game.pickup_settings.points_for(definition)
	note.configure(definition, points, game.pickup_settings.collision_half_size)
	game.world.pickups.items.append(note)
	return note


func _add_car(game: CruiseGame, x: float, y: float) -> TrafficCar:
	var car := CAR_SCENE.instantiate() as TrafficCar
	car.position = Vector2(x, y)
	game.world.traffic.add_child(car)
	car.configure(game.traffic_settings.collision_half_size, Color.WHITE)
	game.world.traffic.vehicles.append(car)
	return car


func _drive(game: CruiseGame, metres: float) -> void:
	var step := 1.0 / 30.0
	var per_step := game.road_settings.scroll_speed * step / game.road_settings.pixels_per_metre
	for _step in range(ceili(metres / per_step)):
		game.advance(step)
		if game.is_game_over:
			return


func _lanes(game: CruiseGame) -> Array[float]:
	var lanes: Array[float] = []
	for fraction in PickupController.LANES:
		lanes.append(lerpf(game.road_settings.left_edge, game.road_settings.right_edge, fraction))
	return lanes


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

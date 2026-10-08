extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const FUEL: FuelSettings = preload("res://src/fuel/default_fuel.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_defaults()
	_test_draining_and_stations()
	_test_refuelling()
	_test_every_car_can_reach_the_station()
	_test_running_out()
	_test_tank_upgrade()
	await _test_gauge()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: methane tank, METAN stations, refuelling, empty tank, and gauge (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_defaults() -> void:
	_check(FUEL.tank_metres == 1500.0, "A full tank lasts 1,500 m")
	_check(
		(
			FUEL.first_station_metres < FUEL.tank_metres
			and FUEL.station_metres_max * 2.0 < FUEL.tank_metres
		),
		"After a refuel, missing one station still leaves fuel to reach the next"
	)


func _test_draining_and_stations() -> void:
	var game := _new_game()
	var fuel := game.world.fuel
	_check(is_equal_approx(fuel.share(), 1.0), "Drives start with a full tank")
	_drive(game, 300.0)
	_check(
		absf(fuel.fuel_metres - (FUEL.tank_metres - game.distance_metres)) < 0.01,
		"The tank drains by distance driven"
	)
	_check(fuel.stations.is_empty(), "No station before 550 m")
	_drive(game, 255.0)
	_check(fuel.stations.size() == 1, "A station appears after 550 m")
	_check(fuel.stations[0].position.x == ROAD.left_edge, "Stations stand at the left curb")
	var first_seen := game.distance_metres
	var spawned_at: Array[float] = []
	var seen := {fuel.stations[0].get_instance_id(): true}
	var step := 1.0 / 30.0
	while not game.is_game_over and game.distance_metres < 2000.0:
		game.advance(step)
		_check_one_station(fuel)
		for station in fuel.stations:
			if not seen.has(station.get_instance_id()):
				seen[station.get_instance_id()] = true
				spawned_at.append(game.distance_metres)
	_check(spawned_at.size() >= 1, "Stations keep coming")
	var gap := spawned_at[0] - first_seen if not spawned_at.is_empty() else 0.0
	_check(gap >= 499.0 and gap <= 701.0, "Stations come every 500 to 700 m")
	_check(
		game.is_game_over and absf(game.distance_metres - FUEL.tank_metres) < 1.0,
		"Without refuelling a tank lasts 1,500 m"
	)
	_check(game.refuels == 0, "Driving in the middle never refuels")
	game.free()


func _check_one_station(fuel: FuelController) -> void:
	if fuel.stations.size() > 1:
		_check(false, "At most one station at a time")


func _test_refuelling() -> void:
	var game := _new_game()
	var fuel := game.world.fuel
	_drive(game, 555.0)
	var before := fuel.fuel_metres
	var station := fuel.stations[0]
	game.world.player.position.x = game.world.player.left_limit
	_drive(game, 40.0)
	_check(not station.is_open, "Hugging the left curb beside the station fills up")
	_check(game.refuels == 1, "The refuel is counted for achievements")
	_check(fuel.fuel_metres > before, "The tank is full again")
	_check(game.hud.drive.pickup_label.text == "Tank full!", "Refuel feedback is shown")
	_drive(game, 40.0)
	_check(game.refuels == 1, "A station refuels once")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(fuel.stations.is_empty() and is_equal_approx(fuel.share(), 1.0), "Restart refills")
	game.free()


func _test_every_car_can_reach_the_station() -> void:
	for car in GARAGE.cars:
		var half := car.settings.collision_half_size.x
		var left := ROAD.left_edge + car.settings.road_margin - half
		_check(left < ROAD.left_edge + FUEL.refuel_distance, "%s can reach the refuel bay" % car.id)
		var centre := (ROAD.left_edge + ROAD.right_edge) * 0.5 - half
		_check(centre > ROAD.left_edge + FUEL.refuel_distance, "Centre driving misses it")


func _test_running_out() -> void:
	var game := _new_game()
	var fuel := game.world.fuel
	game.world.pickups.effects.activate("shield")
	fuel.fuel_metres = FUEL.tank_metres * FUEL.low_share + 5.0
	_drive(game, 4.0)
	_check(game.hud.drive.fuel_gauge.low == false, "Above a quarter the gauge is normal")
	_drive(game, 2.0)
	_check(game.hud.drive.fuel_gauge.low, "Below a quarter the gauge turns red")
	_check(
		game.hud.drive.pickup_label.text == "Low on methane! Find METAN", "A low-fuel warning shows"
	)
	game.hud.drive.dismiss_text()
	_drive(game, 2.0)
	_check(not game.hud.drive.pickup_label.visible, "The warning shows once per tank")
	fuel.fuel_metres = 3.0
	_drive(game, 5.0)
	_check(game.is_game_over, "An empty tank ends the drive, even with a shield")
	var results := game.hud.game_over_panel
	_check(
		results.message_label.text == "Out of methane! Fill up at METAN stations.",
		"Results explain the empty tank"
	)
	_check(game.progress.best_score == game.score, "The run is recorded like any other")
	game.free()


func _test_tank_upgrade() -> void:
	var game := _new_game()
	game.world.traffic.contacted.emit()
	game.open_garage()
	game.progress.wallet = 10000
	game.garage_action("upgrade", "tank")
	game.garage_action("upgrade", "tank")
	var fuel := game.world.fuel
	_check(is_equal_approx(fuel.capacity_metres, FUEL.tank_metres * 1.5), "Two tank levels +50%")
	_check(is_equal_approx(FUEL.tank_metres, 1500.0), "Shared fuel settings never change")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(is_equal_approx(fuel.fuel_metres, fuel.capacity_metres), "The bigger tank starts full")
	game.free()


func _test_gauge() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	for locale in ProgressData.LANGUAGES:
		game.set_language(locale)
		_check(not game.hud.drive.fuel_gauge.visible, "The gauge is hidden in menus: " + locale)
	game.start_run()
	game.world.player.set_physics_process(false)
	await process_frame
	var drive := game.hud.drive
	_check(drive.fuel_gauge.visible, "The gauge shows while driving")
	var gauge := drive.fuel_gauge.get_global_rect()
	for other: Control in [
		drive.best_label, drive.score_label, drive.pause_button, drive.power_up_bar
	]:
		_check(not gauge.intersects(other.get_global_rect()), "The gauge overlaps nothing")
	_check(Rect2(0, 0, 432, 768).encloses(gauge), "The gauge is on screen")
	game.pause_run()
	_check(not drive.fuel_gauge.visible, "The gauge hides when paused")
	view.free()


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 1.0e9
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0e9
	var traffic := game.get_node("World/Traffic") as TrafficController
	traffic.sheep_settings = traffic.sheep_settings.duplicate() as SheepSettings
	traffic.sheep_settings.first_crossing_metres = 1.0e9
	var pickups := game.get_node("World/Pickups") as PickupController
	pickups.power_up_settings = pickups.power_up_settings.duplicate() as PowerUpSettings
	pickups.power_up_settings.first_spawn_metres = 1.0e9
	pickups.passenger_settings = pickups.passenger_settings.duplicate() as PassengerSettings
	pickups.passenger_settings.first_stop_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	# Queues and police posts change refuelling and station timing; their own suites cover them.
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.queue_chance = 0.0
	var police := game.get_node("World/Police") as PoliceController
	police.settings = police.settings.duplicate() as PoliceSettings
	police.settings.first_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _drive(game: CruiseGame, metres: float) -> void:
	var step := 1.0 / 30.0
	var per_step := game.road_settings.scroll_speed * step / game.road_settings.pixels_per_metre
	for _step in range(ceili(metres / per_step)):
		game.advance(step)
		if game.is_game_over:
			return


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

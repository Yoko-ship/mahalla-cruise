extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const FUEL: FuelSettings = preload("res://src/fuel/default_fuel.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_queue_appears()
	_test_partial_fill()
	_test_waiting_with_the_brake()
	_test_no_queue()
	_test_every_car_can_wait()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: METAN queues, waiting, partial fills, and braking (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_queue_appears() -> void:
	var game := _new_game(1.0)
	var station := _wait_for_station(game)
	_check(station.queue >= 1 and station.queue <= FUEL.queue_max, "One to three cars wait")
	_check(
		game.hud.drive.pickup_label.text == "METAN queue %d! Brake in the bay" % station.queue,
		"The queue is announced"
	)
	game.free()
	game = _new_game(0.0)
	_check(_wait_for_station(game).queue == 0, "Some stations have no queue")
	game.free()


func _test_partial_fill() -> void:
	var game := _new_game(1.0)
	var fuel := game.world.fuel
	var station := _wait_for_station(game)
	station.configure(FUEL.zone_height, FUEL.refuel_distance, 3)
	fuel.fuel_metres = fuel.capacity_metres * 0.4
	var player := game.world.player
	player.position.x = player.left_limit
	_drive_past(game, station)
	_check(not station.is_open, "Driving on serves the station")
	_check(game.refuels == 0, "A partial fill is not a full refuel")
	var share := fuel.share()
	_check(share > 0.45 and share < 0.95, "Part of the tank is filled (%d%%)" % roundi(share * 100))
	_check(
		game.hud.drive.pickup_label.text == "Partly filled: tank %d%%" % roundi(share * 100),
		"The partial fill is shown"
	)
	game.free()


func _test_waiting_with_the_brake() -> void:
	var game := _new_game(1.0)
	var fuel := game.world.fuel
	var station := _wait_for_station(game)
	station.configure(FUEL.zone_height, FUEL.refuel_distance, 2)
	fuel.fuel_metres = fuel.capacity_metres * 0.3
	var player := game.world.player
	player.position.x = player.left_limit
	game.world.set_braking(true)
	_drive_past(game, station)
	_check(game.refuels == 1 and fuel.share() > 0.99, "Braking waits for a full tank")
	_check(game.hud.drive.pickup_label.text == "Tank full!", "The full tank is shown")
	game.free()


func _test_no_queue() -> void:
	var game := _new_game(0.0)
	var fuel := game.world.fuel
	var station := _wait_for_station(game)
	fuel.fuel_metres = fuel.capacity_metres * 0.3
	game.world.player.position.x = game.world.player.left_limit
	_drive_past(game, station)
	_check(game.refuels == 1 and fuel.share() > 0.99, "No queue fills at full speed")
	game.free()


func _test_every_car_can_wait() -> void:
	for car in GARAGE.cars:
		var half := car.settings.collision_half_size.y
		var braked := ROAD.scroll_speed * car.settings.travel_speed_scale
		braked *= car.settings.brake_speed_share
		var seconds := (FUEL.zone_height + half * 2.0) / braked
		var needed := 2 * FUEL.wait_seconds_per_car
		_check(seconds >= needed, "%s can wait out a queue of two by braking" % car.id)


func _wait_for_station(game: CruiseGame) -> FuelStation:
	while game.world.fuel.stations.is_empty() and game.distance_metres < 3000.0:
		game.advance(STEP)
	return game.world.fuel.stations[0]


func _drive_past(game: CruiseGame, station: FuelStation) -> void:
	var guard := 0
	while station.is_open and guard < 3000:
		game.advance(STEP)
		guard += 1


func _new_game(queue_chance: float) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 1.0e9
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0e9
	var world := game.get_node("World")
	var traffic := world.get_node("Traffic") as TrafficController
	traffic.sheep_settings = traffic.sheep_settings.duplicate() as SheepSettings
	traffic.sheep_settings.first_crossing_metres = 1.0e9
	var pickups := world.get_node("Pickups") as PickupController
	pickups.power_up_settings = pickups.power_up_settings.duplicate() as PowerUpSettings
	pickups.power_up_settings.first_spawn_metres = 1.0e9
	pickups.passenger_settings = pickups.passenger_settings.duplicate() as PassengerSettings
	pickups.passenger_settings.first_stop_metres = 1.0e9
	var hazards := world.get_node("Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := world.get_node("Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.queue_chance = queue_chance
	var cameras := world.get_node("Cameras") as SpeedCameraController
	cameras.settings = cameras.settings.duplicate() as SpeedCameraSettings
	cameras.settings.first_metres = 1.0e9
	var taxi := world.get_node("Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
	var police := world.get_node("Police") as PoliceController
	police.settings = police.settings.duplicate() as PoliceSettings
	police.settings.first_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

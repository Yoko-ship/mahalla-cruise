extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const SETTINGS: PassengerSettings = preload("res://src/pickups/default_passengers.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stops_appear()
	_test_boarding()
	_test_every_car_can_reach_the_curb()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: bus stops, curbside boarding, fares, and reset (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_stops_appear() -> void:
	var game := _new_game()
	var pickups := game.world.pickups
	_drive(game, 190.0)
	_check(pickups.bus_stops.is_empty(), "No stop before 200 m")
	_drive(game, 15.0)
	_check(pickups.bus_stops.size() == 1, "A stop appears after 200 m")
	var stop := pickups.bus_stops[0]
	_check(stop.position.x == game.road_settings.right_edge, "Stops stand at the right curb")
	_check(stop.passengers >= 1 and stop.passengers <= 3, "One to three passengers wait")
	_drive(game, 60.0)
	_check(game.score == 0 and stop.passengers > 0, "Driving past in the middle boards nobody")
	_drive(game, 60.0)
	_check(pickups.bus_stops.is_empty(), "Passed stops are removed")
	var seen := {}
	var step := 1.0 / 30.0
	for _step in range(ceili(SETTINGS.stop_metres_max * 3.0 / (220.0 * step / 20.0))):
		game.advance(step)
		for later in pickups.bus_stops:
			seen[later.get_instance_id()] = true
	_check(seen.size() >= 2, "Stops keep coming")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(pickups.bus_stops.is_empty(), "Restart clears stops")
	game.free()


func _test_boarding() -> void:
	var game := _new_game()
	_drive(game, 205.0)
	var stop := game.world.pickups.bus_stops[0]
	var waiting := stop.passengers
	game.world.player.position.x = game.world.player.right_limit
	_drive(game, 60.0)
	_check(stop.passengers == 0, "Hugging the curb boards everyone")
	_check(game.score == waiting * 5, "Each passenger pays 5 points")
	_check(game.som_collected == waiting, "Fares count as soʻm notes")
	_check(
		game.hud.drive.pickup_label.text.begins_with("5 000 soʻm"), "Fare feedback shows the note"
	)
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_drive(game, 205.0)
	game.world.pickups.effects.activate("double")
	stop = game.world.pickups.bus_stops[0]
	waiting = stop.passengers
	game.world.player.position.x = game.world.player.right_limit
	_drive(game, 60.0)
	_check(game.score == waiting * 10, "Double points doubles fares")
	game.free()


func _test_every_car_can_reach_the_curb() -> void:
	var road := ROAD
	for car in GARAGE.cars:
		var right := road.right_edge - car.settings.road_margin + car.settings.collision_half_size.x
		_check(
			right > road.right_edge - SETTINGS.board_distance,
			"%s can reach the boarding zone" % car.id
		)
		var centre := (road.left_edge + road.right_edge) * 0.5 + car.settings.collision_half_size.x
		_check(centre < road.right_edge - SETTINGS.board_distance, "Centre driving misses it")


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
	# The long drive below never steers to a METAN station; fuel is tested elsewhere.
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	# Taxi orders hold bus stops while busy; taxi_test covers that.
	var taxi := game.get_node("World/Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
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


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

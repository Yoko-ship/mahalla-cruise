extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const TAXI: TaxiSettings = preload("res://src/taxi/default_taxi.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_hail()
	_test_ride_and_fare()
	_test_missed_drop_off()
	_test_curb_sharing()
	_test_every_car_can_reach_the_curb()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: taxi hails, rides, drop-offs, fares, and curb sharing (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_hail() -> void:
	var game := _new_game(false)
	var taxi := game.world.taxi
	_drive(game, TAXI.first_order_metres - 5.0)
	_check(taxi.spots.is_empty(), "No taxi call before 350 m")
	_drive(game, 10.0)
	_check(taxi.spots.size() == 1 and not taxi.spots[0].is_drop_off, "A passenger hails")
	var hail := taxi.spots[0]
	_check(hail.position.x == ROAD.right_edge, "Passengers hail from the right curb")
	_check(game.hud.drive.pickup_label.text == "Taxi! Pull over right", "The call is announced")
	_check(taxi.is_busy() and not taxi.is_riding, "A waiting hail keeps the curb busy")
	_drive(game, 60.0)
	_check(not taxi.is_riding and not hail.is_served, "Driving past in the middle picks nobody up")
	_check(game.hud.drive.ride_chip.text().is_empty(), "No ride chip without a passenger")
	var called_at := -1.0
	var gone := false
	while called_at < 0.0 and game.distance_metres < 2500.0:
		game.advance(STEP)
		gone = gone or taxi.spots.is_empty()
		if gone and not taxi.spots.is_empty():
			called_at = game.distance_metres
	_check(gone, "A missed hail is removed")
	var gap := called_at - TAXI.first_order_metres
	_check(gap >= TAXI.order_metres_min, "The next call waits after a missed hail (%d m)" % gap)
	_check(gap <= TAXI.order_metres_max + 80.0, "Calls keep coming (%d m)" % gap)
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(taxi.spots.is_empty() and not taxi.is_busy(), "Restart clears taxi orders")
	game.free()


func _test_ride_and_fare() -> void:
	var game := _new_game(false)
	var taxi := game.world.taxi
	var player := game.world.player
	_board(game)
	_check(taxi.is_riding, "Pulling in beside the hail picks the passenger up")
	var ride := taxi.ride_metres()
	_check(ride >= TAXI.ride_metres_min and ride <= TAXI.ride_metres_max, "Ride length in range")
	_check(
		game.hud.drive.pickup_label.text == "Passenger in! Drop-off in %d m" % ride,
		"The ride length is announced"
	)
	player.position.x = (ROAD.left_edge + ROAD.right_edge) * 0.5
	player.target_x = player.position.x
	_drive(game, 20.0)
	var left := taxi.ride_metres()
	_check(left < ride and left > ride - 25, "The ride counts down")
	_check(game.hud.drive.ride_chip.text() == "Drop-off %d m" % left, "The chip shows metres left")
	var drop := _wait_for_drop_off(game)
	_check(drop != null and drop.position.x == ROAD.right_edge, "The drop-off is at the right curb")
	if drop == null:
		game.free()
		return
	_check(drop.position.y < 0.0, "The drop-off arrives from beyond the top of the screen")
	while drop.position.y < player.position.y:
		game.advance(STEP)
	_check(absf(taxi.ride_left) < 0.5, "The bay reaches the car when the ride ends")
	_check(game.hud.drive.ride_chip.text() == "Pull over right!", "The chip asks to pull over")
	game.world.pickups.effects.activate("double")
	player.position.x = player.right_limit
	_drive(game, 2.0)
	var notes := TAXI.notes_for(ride)
	_check(notes >= 3 and notes <= 5, "Fares are 3 to 5 notes")
	_check(drop.is_served and not taxi.is_riding, "Pulling into the bay drops the passenger off")
	_check(game.score == notes * 10 * 2, "Each 10,000 soʻm note pays; double points applies")
	_check(game.som_collected == notes, "Fares count as soʻm notes")
	_check(
		game.hud.drive.pickup_label.text == "Fare paid!  +%d pts" % game.score,
		"The total fare is shown"
	)
	_check(taxi.ride_metres() == -1 and game.hud.drive.ride_chip.text().is_empty(), "Chip hides")
	_drive(game, 40.0)
	_check(game.score == notes * 20, "A ride pays once")
	game.free()


func _test_missed_drop_off() -> void:
	var game := _new_game(false)
	var taxi := game.world.taxi
	var player := game.world.player
	_board(game)
	player.position.x = (ROAD.left_edge + ROAD.right_edge) * 0.5
	player.target_x = player.position.x
	var drop := _wait_for_drop_off(game)
	while drop.position.y < player.position.y + 60.0:
		game.advance(STEP)
	_check(taxi.is_riding, "The ride lasts until the bay is fully behind the car")
	_drive(game, 1.0)
	_check(not taxi.is_riding and not drop.is_served, "Driving past the bay loses the passenger")
	_check(game.score == 0, "A missed drop-off pays nothing")
	_check(
		game.hud.drive.pickup_label.text == "Missed the drop-off! No fare", "The miss is announced"
	)
	player.position.x = player.right_limit
	_drive(game, 20.0)
	_check(game.score == 0, "Swerving back after missing pays nothing")
	game.free()


func _test_curb_sharing() -> void:
	var game := _new_game(true)
	var taxi := game.world.taxi
	var pickups := game.world.pickups
	# The stop is due at 5 m and the taxi at 10 m: the hail waits for the stop to leave.
	var waited := false
	while taxi.spots.is_empty() and game.distance_metres < 200.0:
		game.advance(STEP)
		if not pickups.bus_stops.is_empty():
			waited = waited or game.distance_metres > 10.0
		_check_one_curb_user(taxi, pickups)
	_check(waited, "A bus stop was on the curb when the taxi was due")
	_check(not taxi.spots.is_empty(), "The hail comes once the stop has gone")
	_board(game)
	_check(pickups.hold_stops, "Bus stops wait while a passenger rides")
	while taxi.is_riding and game.distance_metres < 1200.0:
		game.advance(STEP)
		if not pickups.bus_stops.is_empty():
			_check(false, "No bus stop during a ride")
			break
	game.free()


func _check_one_curb_user(taxi: TaxiController, pickups: PickupController) -> void:
	if not taxi.spots.is_empty() and not pickups.bus_stops.is_empty():
		_check(false, "A hail and a bus stop never share the curb")


func _test_every_car_can_reach_the_curb() -> void:
	for car in GARAGE.cars:
		var half := car.settings.collision_half_size.x
		var right := ROAD.right_edge - car.settings.road_margin + half
		_check(right > ROAD.right_edge - TAXI.board_distance, "%s can pull in" % car.id)
		var centre := (ROAD.left_edge + ROAD.right_edge) * 0.5 + half
		_check(centre < ROAD.right_edge - TAXI.board_distance, "Centre driving passes by")


## Drives to the first hail and hugs the curb until the passenger is aboard.
func _board(game: CruiseGame) -> void:
	var taxi := game.world.taxi
	while taxi.spots.is_empty() and game.distance_metres < 1000.0:
		game.advance(STEP)
	game.world.player.position.x = game.world.player.right_limit
	while not taxi.is_riding and not taxi.spots.is_empty():
		game.advance(STEP)


func _wait_for_drop_off(game: CruiseGame) -> TaxiSpot:
	var taxi := game.world.taxi
	while taxi.is_riding:
		for spot in taxi.spots:
			if spot.is_drop_off:
				return spot
		game.advance(STEP)
	return null


## stops_on: bus stops come at 5 m and the taxi at 10 m; everything else stays off.
func _new_game(stops_on: bool) -> CruiseGame:
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
	pickups.passenger_settings.first_stop_metres = 5.0 if stops_on else 1.0e9
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	var night := game.get_node("World/Night") as NightView
	night.settings = night.settings.duplicate() as NightSettings
	night.settings.start_metres = 1.0e9
	var cameras := game.get_node("World/Cameras") as SpeedCameraController
	cameras.settings = cameras.settings.duplicate() as SpeedCameraSettings
	cameras.settings.first_metres = 1.0e9
	if stops_on:
		var taxi := game.get_node("World/Taxi") as TaxiController
		taxi.settings = taxi.settings.duplicate() as TaxiSettings
		taxi.settings.first_order_metres = 10.0
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _drive(game: CruiseGame, metres: float) -> void:
	var start := game.distance_metres
	while game.distance_metres - start < metres and not game.is_game_over:
		game.advance(STEP)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

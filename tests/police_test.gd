extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const POLICE: PoliceSettings = preload("res://src/police/default_police.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_post_appears()
	_test_stopping()
	_test_not_stopping()
	_test_quiet_post()
	_test_curb_sharing()
	_test_every_car_can_stop()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: GAI posts, stopping, fines, rewards, and curb sharing (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_post_appears() -> void:
	var game := _new_game(1.0, false)
	var police := game.world.police
	_drive(game, POLICE.first_metres - 5.0)
	_check(police.posts.is_empty(), "No post before 600 m")
	_drive(game, 10.0)
	_check(police.posts.size() == 1, "A post appears after 600 m")
	var post := police.posts[0]
	_check(post.position.x == ROAD.left_edge and post.waving, "At the left curb, waving")
	_check(
		game.hud.drive.pickup_label.text == "GAI post! Pull over left, slowly", "Drivers are warned"
	)
	_check(game.hud.drive.speedometer.limit_kmh == POLICE.stop_kmh, "The stop speed is shown")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(police.posts.is_empty(), "Restart clears posts")
	game.free()


func _test_stopping() -> void:
	for route in ["tashkent", "samarkand"]:
		var game := _new_game(1.0, false)
		if route != "tashkent":
			game.world.traffic.contacted.emit()
			game.open_garage()
			game.progress.wallet = 5000
			game.garage_action("route", route)
			game.hud.garage_menu.close()
			game.restart_run()
			game.start_run()
			game.world.player.set_physics_process(false)
		var post := _wait_for_post(game)
		game.score = 50
		game.world.set_braking(true)
		game.world.player.position.x = game.world.player.left_limit
		_drive_until_done(game, post)
		var reward := 20 if route == "tashkent" else 23
		_check(game.score == 50 + reward, "Stopping slowly earns %d in %s" % [reward, route])
		_check(
			game.hud.drive.pickup_label.text == "Documents in order!  +%d pts" % reward,
			"The officer thanks the driver"
		)
		_check(game.pickup_feedback.dollar_sound.playing, "A reward chime plays")
		_check(game.hud.drive.speedometer.limit_kmh == 0, "The stop sign clears")
		game.free()


func _test_not_stopping() -> void:
	for hug_curb in [true, false]:
		var game := _new_game(1.0, false)
		var post := _wait_for_post(game)
		game.score = 50
		if hug_curb:
			game.world.player.position.x = game.world.player.left_limit
		_drive_until_done(game, post)
		_check(game.score == 20, "Not stopping costs 30 (curb: %s)" % hug_curb)
		_check(
			game.hud.drive.pickup_label.text == "Didn't stop for GAI!  −30 pts", "The fine is shown"
		)
		_check(game.pickup_feedback.whistle_sound.playing, "The officer whistles")
		_check(not game.is_game_over, "A fine never ends the drive")
		_drive(game, 40.0)
		_check(game.score == 20, "One fine per post")
		game.free()


func _test_quiet_post() -> void:
	var game := _new_game(0.0, false)
	var post := _wait_for_post(game)
	game.score = 50
	_check(not post.waving and game.hud.drive.speedometer.limit_kmh == 0, "Some officers watch")
	_check(not game.hud.drive.pickup_label.visible, "Quiet posts say nothing")
	_drive(game, 50.0)
	_check(game.score == 50, "Passing a quiet post costs nothing")
	game.free()


func _test_curb_sharing() -> void:
	var game := _new_game(0.6, true)
	var police := game.world.police
	var fuel := game.world.fuel
	var posts := {}
	var stations := {}
	var shared := false
	while game.distance_metres < 8000.0 and not game.is_game_over:
		game.advance(STEP)
		for post in police.posts:
			posts[post.get_instance_id()] = true
		for station in fuel.stations:
			stations[station.get_instance_id()] = true
		shared = shared or (not police.posts.is_empty() and not fuel.stations.is_empty())
	_check(not shared, "A post and a METAN station never share the left curb")
	_check(
		posts.size() >= 5 and stations.size() >= 5,
		"Both keep coming (%d, %d)" % [posts.size(), stations.size()]
	)
	game.free()


func _test_every_car_can_stop() -> void:
	for car in GARAGE.cars:
		var full := ROAD.scroll_speed * car.settings.travel_speed_scale
		var braked := ROAD.kmh(full * car.settings.brake_speed_share)
		_check(
			braked <= POLICE.stop_kmh, "%s can stop for the officer (%d km/h)" % [car.id, braked]
		)
		var half := car.settings.collision_half_size.x
		var left := ROAD.left_edge + car.settings.road_margin - half
		_check(left < ROAD.left_edge + POLICE.stop_distance, "%s reaches the stop bay" % car.id)


func _wait_for_post(game: CruiseGame) -> PolicePost:
	while game.world.police.posts.is_empty() and game.distance_metres < 3000.0:
		game.advance(STEP)
	return game.world.police.posts[0]


func _drive_until_done(game: CruiseGame, post: PolicePost) -> void:
	var guard := 0
	while not post.is_done and guard < 3000:
		game.advance(STEP)
		guard += 1


## wave: the officers' wave chance; stations: keep METAN stations (with an endless tank).
func _new_game(wave: float, stations: bool) -> CruiseGame:
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
	fuel.settings.tank_metres = 1.0e9
	if not stations:
		fuel.settings.first_station_metres = 1.0e9
	var night := world.get_node("Night") as NightView
	night.settings = night.settings.duplicate() as NightSettings
	night.settings.start_metres = 1.0e9
	var cameras := world.get_node("Cameras") as SpeedCameraController
	cameras.settings = cameras.settings.duplicate() as SpeedCameraSettings
	cameras.settings.first_metres = 1.0e9
	var taxi := world.get_node("Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
	var police := world.get_node("Police") as PoliceController
	police.settings = police.settings.duplicate() as PoliceSettings
	police.settings.wave_chance = wave
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

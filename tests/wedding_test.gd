extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const WEDDING: WeddingSettings = preload("res://src/wedding/default_wedding.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_convoy_waits_for_traffic()
	_test_sochqi()
	_test_convoy_keeps_its_lane()
	_test_pick_value()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: wedding convoys, traffic hold, sochqi, and lane blocking (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_convoy_waits_for_traffic() -> void:
	var game := _new_game(true)
	var wedding := game.world.wedding
	var traffic := game.world.traffic
	_drive(game, WEDDING.first_metres - 5.0)
	_check(wedding.cars.is_empty() and not traffic.hold_spawns, "No convoy before 700 m")
	_drive(game, 10.0)
	_check(traffic.hold_spawns, "A due convoy holds traffic spawns")
	var waited := 0
	while wedding.cars.is_empty() and waited < 600:
		_check(not traffic.vehicles.is_empty(), "The convoy waits only while cars remain")
		var count := traffic.vehicles.size()
		game.advance(STEP)
		_check(traffic.vehicles.size() <= count, "No car spawns while the convoy is due")
		waited += 1
	_check(not wedding.cars.is_empty(), "The convoy arrives once the road is clear")
	_check(wedding.cars.size() == WEDDING.cars, "Three cars in the convoy")
	_check(wedding.cars[0].is_lead and not wedding.cars[1].is_lead, "Only the lead has balloons")
	_check(
		game.hud.drive.pickup_label.text == "Wedding convoy! Follow it",
		"Drivers are told to follow"
	)
	_check(game.pickup_feedback.karnay_sound.playing, "The karnay plays")
	var lanes := [
		lerpf(ROAD.left_edge, ROAD.right_edge, 0.25), lerpf(ROAD.left_edge, ROAD.right_edge, 0.75)
	]
	_check(wedding.lane_x in lanes, "The convoy drives in a lane")
	# Ride out the whole event; no convoy car may ever reach the player.
	var player := game.world.player
	var frames := 0
	var cruised := false
	while not wedding.cars.is_empty() and frames < 3000:
		game.advance(STEP)
		frames += 1
		cruised = cruised or wedding.phase == WeddingController.Phase.CRUISING
		for car in wedding.cars:
			if car.collision_bounds().end.y >= player.collision_bounds().position.y:
				_check(false, "A convoy car reached the player")
				break
		_check(traffic.vehicles.is_empty() or wedding.cars.is_empty(), "No traffic with a convoy")
	_check(cruised, "The convoy cruises ahead before leaving")
	_check(wedding.cars.is_empty() and not game.is_game_over, "The convoy drives off")
	game.advance(STEP)
	_check(not traffic.hold_spawns, "The hold is released once the convoy is gone")
	game.world.traffic.contacted.emit()
	game.free()


func _test_sochqi() -> void:
	var game := _new_game(false)
	var wedding := game.world.wedding
	_drive(game, WEDDING.first_metres + 1.0)
	_check(not wedding.cars.is_empty(), "Without traffic the convoy arrives at once")
	var tossed := [0]
	wedding.tossed.connect(func(_spot: Vector2, _value: int) -> void: tossed[0] += 1)
	var player := game.world.player
	var frames := 0
	while wedding.phase != WeddingController.Phase.LEAVING and frames < 3000:
		player.position.x = wedding.lane_x
		game.advance(STEP)
		frames += 1
		for note in game.world.pickups.items:
			if note.position.y < wedding.cars.back().collision_bounds().end.y:
				_check(false, "Sochqi never lands beside or ahead of the convoy")
	var expected := (
		floori(
			(
				(WEDDING.cruise_metres * ROAD.pixels_per_metre - WEDDING.toss_pixels * 0.5)
				/ WEDDING.toss_pixels
			)
		)
		+ 1
	)
	_check(tossed[0] == expected * WEDDING.notes_per_toss, "Handfuls land through the cruise")
	_drive(game, 30.0)
	_check(game.som_collected >= tossed[0] - 3, "Following in the lane collects the sochqi")
	_check(game.score > 0, "Sochqi pays points")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(wedding.cars.is_empty() and not wedding.wants_road(), "Restart clears the convoy")
	game.free()


func _test_convoy_keeps_its_lane() -> void:
	var game := _new_game(false, true)
	var wedding := game.world.wedding
	var pickups := game.world.pickups
	var seen := {}
	var dropped := [0]
	var in_lane := 0
	wedding.tossed.connect(func(_spot: Vector2, _value: int) -> void: dropped[0] += 1)
	_drive(game, WEDDING.first_metres + 1.0)
	for note in pickups.items:
		seen[note.get_instance_id()] = true
	var frames := 0
	while not wedding.cars.is_empty() and frames < 3000:
		game.advance(STEP)
		frames += 1
		for note in pickups.items:
			if seen.has(note.get_instance_id()):
				continue
			seen[note.get_instance_id()] = true
			if absf(note.position.x - wedding.lane_x) < WEDDING.toss_spread + 1.0:
				in_lane += 1
	_check(dropped[0] > 0 and in_lane == dropped[0], "Only sochqi appears in the convoy lane")
	_check(seen.size() > in_lane, "Normal money keeps spawning in the other lanes")
	game.world.traffic.contacted.emit()
	game.free()


func _test_pick_value() -> void:
	_check(WEDDING.pick_value(0.0) == 1000, "Mostly 1,000 soʻm notes")
	_check(WEDDING.pick_value(0.7) == 5000, "Some 5,000 soʻm notes")
	_check(WEDDING.pick_value(0.99) == 10000, "A few 10,000 soʻm notes")


## traffic: keep normal traffic (crashes are absorbed); money: keep normal note spawns.
func _new_game(traffic: bool, money: bool = false) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	if not traffic:
		game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
		game.traffic_settings.first_spawn_distance = 1.0e9
	if not money:
		game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
		game.pickup_settings.first_spawn_distance = 1.0e9
	var sheep := game.get_node("World/Traffic") as TrafficController
	sheep.sheep_settings = sheep.sheep_settings.duplicate() as SheepSettings
	sheep.sheep_settings.first_crossing_metres = 1.0e9
	var pickups := game.get_node("World/Pickups") as PickupController
	pickups.power_up_settings = pickups.power_up_settings.duplicate() as PowerUpSettings
	pickups.power_up_settings.first_spawn_metres = 1.0e9
	pickups.passenger_settings = pickups.passenger_settings.duplicate() as PassengerSettings
	pickups.passenger_settings.first_stop_metres = 1.0e9
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	var cameras := game.get_node("World/Cameras") as SpeedCameraController
	cameras.settings = cameras.settings.duplicate() as SpeedCameraSettings
	cameras.settings.first_metres = 1.0e9
	var taxi := game.get_node("World/Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
	var police := game.get_node("World/Police") as PoliceController
	police.settings = police.settings.duplicate() as PoliceSettings
	police.settings.first_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	# Traffic tests ride through; a long grace absorbs any contact with ordinary cars.
	game.world.pickups.effects.grace_metres = 1.0e9
	return game


func _drive(game: CruiseGame, metres: float) -> void:
	var per_step := ROAD.scroll_speed * STEP / ROAD.pixels_per_metre
	for _step in range(ceili(metres / per_step)):
		game.advance(STEP)
		if game.is_game_over:
			return


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

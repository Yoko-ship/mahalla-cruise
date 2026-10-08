extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const HAZARDS: HazardSettings = preload("res://src/hazards/default_hazards.tres")
const HAZARD_SCENE: PackedScene = preload("res://src/hazards/road_hazard.tscn")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const FUEL: FuelSettings = preload("res://src/fuel/default_fuel.tres")
const PASSENGERS: PassengerSettings = preload("res://src/pickups/default_passengers.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_spawning()
	_test_hits()
	_test_suspension()
	_test_curb_zones_stay_clear()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: potholes, road works, penalties, safe placement, and suspension (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_spawning() -> void:
	var game := _new_game(false)
	var hazards := game.world.hazards
	# Move the car off the road so the long drive measures placement, not crashes or hits.
	game.world.player.position.x = -500.0
	_drive(game, HAZARDS.first_metres - 5.0)
	_check(hazards.hazards.is_empty(), "No hazards before 250 m")
	var kinds := {}
	var spawned := 0
	var off_centre := 0
	var on_money := 0
	var on_traffic := 0
	var centre := (ROAD.left_edge + ROAD.right_edge) * 0.5
	var seen := {}
	for _step in range(36000):
		game.advance(1.0 / 30.0)
		if game.is_game_over:
			break
		var player_y := game.world.player.position.y
		for hazard in hazards.hazards:
			if not seen.has(hazard.get_instance_id()):
				seen[hazard.get_instance_id()] = true
				spawned += 1
				kinds[hazard.kind] = true
				off_centre += int(absf(hazard.position.x - centre) > HAZARDS.centre_spread + 0.01)
			var bounds := hazard.collision_bounds()
			for note in game.world.pickups.item_bounds():
				on_money += int(note.intersects(bounds))
			# Cars may drive over flat potholes, but never through a barrier before the player.
			if hazard.kind == "works" and hazard.position.y < player_y:
				for vehicle in game.world.traffic.vehicles:
					on_traffic += int(vehicle.collision_bounds().intersects(bounds))
	_check(not game.is_game_over, "The car off the road drives the whole test")
	_check(kinds.size() == 2, "Both potholes and road works appear")
	_check(spawned >= 20, "Hazards keep coming (%d)" % spawned)
	_check(off_centre == 0, "Hazards stay near the centre line")
	_check(on_money == 0, "Hazards never overlap money")
	_check(on_traffic == 0, "Road works never spawn into a car's path")
	game.free()


func _test_hits() -> void:
	var game := _new_game(true)
	game.score = 15
	var pothole := _add(game, "pothole")
	_drive(game, 6.0)
	_check(pothole.is_hit, "Driving over a pothole hits it")
	_check(game.score == 5, "A pothole costs 10 points")
	_check(not game.is_game_over, "Hazards never end the drive")
	_check(game.hud.drive.pickup_label.text == "Pothole!  −10 pts", "Pothole feedback shows")
	_check(game.hud.drive.score_label.text == "5 pts", "The HUD shows the lower score")
	_check(game.pickup_feedback.bump_sound.playing, "A bump sound plays")
	_drive(game, 6.0)
	_check(game.score == 5, "A hazard costs points once")
	_add(game, "works")
	_drive(game, 6.0)
	_check(game.score == 0, "Points never drop below zero")
	_check(game.hud.drive.pickup_label.text == "Road works!  −20 pts", "Road works feedback shows")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(game.world.hazards.hazards.is_empty(), "Restart clears hazards")
	game.free()


func _test_suspension() -> void:
	var game := _new_game(true)
	game.world.traffic.contacted.emit()
	game.open_garage()
	game.progress.wallet = 10000
	game.garage_action("upgrade", "suspension")
	game.garage_action("upgrade", "suspension")
	_check(game.world.hazards.penalty_for("works") == 10, "Two suspension levels halve penalties")
	_check(HAZARDS.works_penalty == 20, "Shared hazard settings never change")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.score = 30
	_add(game, "works")
	_drive(game, 6.0)
	_check(game.score == 20, "The upgraded car loses fewer points")
	game.free()


func _test_curb_zones_stay_clear() -> void:
	var centre := (ROAD.left_edge + ROAD.right_edge) * 0.5
	var widest := maxf(
		HAZARDS.works_half_size.x, HAZARDS.centre_spread + HAZARDS.pothole_half_size.x
	)
	for car in GARAGE.cars:
		var half := car.settings.collision_half_size.x
		# Positions where the car is just inside the refuel bay or the boarding zone.
		var refuel_right := ROAD.left_edge + FUEL.refuel_distance + half * 2.0
		var board_left := ROAD.right_edge - PASSENGERS.board_distance - half * 2.0
		_check(refuel_right < centre - widest, "%s refuels clear of hazards" % car.id)
		_check(board_left > centre + widest, "%s boards clear of hazards" % car.id)


func _add(game: CruiseGame, kind: String) -> RoadHazard:
	var hazard := HAZARD_SCENE.instantiate() as RoadHazard
	hazard.position = game.world.player.position - Vector2(0, 60)
	game.world.hazards.add_child(hazard)
	hazard.configure(kind, HAZARDS.half_size(kind))
	game.world.hazards.hazards.append(hazard)
	return hazard


func _new_game(quiet: bool) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	var traffic := game.get_node("World/Traffic") as TrafficController
	traffic.sheep_settings = traffic.sheep_settings.duplicate() as SheepSettings
	traffic.sheep_settings.first_crossing_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	var night := game.get_node("World/Night") as NightView
	night.settings = night.settings.duplicate() as NightSettings
	night.settings.start_metres = 1.0e9
	if quiet:
		game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
		game.traffic_settings.first_spawn_distance = 1.0e9
		game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
		game.pickup_settings.first_spawn_distance = 1.0e9
		var hazards := game.get_node("World/Hazards") as HazardController
		hazards.settings = hazards.settings.duplicate() as HazardSettings
		hazards.settings.first_metres = 1.0e9
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

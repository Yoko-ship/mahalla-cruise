extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const CAMERAS: SpeedCameraSettings = preload("res://src/cameras/default_speed_cameras.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_brake()
	_test_every_car_can_slow_enough()
	await _test_pedal_input()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: braking, speed recovery, keyboard brake, and multitouch pedal (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_brake() -> void:
	var game := _new_game(false)
	var world := game.world
	var player := world.player
	var full := ROAD.scroll_speed * STEP
	_check(is_equal_approx(world.travel_pixels(STEP), full), "Full speed without the brake")
	_check(world.speed_kmh() == 60, "A Damas cruises at 60 km/h")
	world.set_braking(true)
	_drive_steps(game, 30)
	var settings := player.settings
	_check(is_equal_approx(player.speed_share, settings.brake_speed_share), "Braking halves speed")
	_check(world.speed_kmh() == 30, "The speedometer reads 30 km/h")
	_check(game.hud.drive.speedometer.speed_kmh == 30, "The HUD shows the braked speed")
	var before := game.distance_metres
	_drive_steps(game, 30)
	var braked_metres := game.distance_metres - before
	_check(
		is_equal_approx(braked_metres, ROAD.scroll_speed * 0.5 / ROAD.pixels_per_metre),
		"Braked travel covers half the distance"
	)
	world.set_braking(false)
	_drive_steps(game, 15)
	_check(player.speed_share > 0.5 and player.speed_share < 1.0, "Speed recovers gradually")
	_drive_steps(game, 30)
	_check(is_equal_approx(player.speed_share, 1.0), "Full speed returns")
	world.set_braking(true)
	game.pause_run()
	_check(not player.is_braking(), "Pausing releases the brake")
	game.resume_run()
	player.set_physics_process(false)
	Input.action_press("ui_down")
	_check(player.is_braking(), "The Down key brakes")
	Input.action_release("ui_down")
	_check(not player.is_braking(), "Releasing the key stops braking")
	world.set_braking(true)
	_drive_steps(game, 30)
	world.traffic.contacted.emit()
	game.restart_run()
	player.set_physics_process(false)
	_check(player.speed_share == 1.0 and not player.is_braking(), "Restart drives at full speed")
	_check(GARAGE.find("damas").settings.brake_speed_share == 0.5, "Shared car settings unchanged")
	game.free()


func _test_every_car_can_slow_enough() -> void:
	var lowest: int = CAMERAS.limits_kmh.min()
	var highest: int = CAMERAS.limits_kmh.max()
	for car in GARAGE.cars:
		var full := ROAD.scroll_speed * car.settings.travel_speed_scale
		var braked := ROAD.kmh(full * car.settings.brake_speed_share)
		_check(braked <= lowest, "%s brakes under every limit (%d km/h)" % [car.id, braked])
		_check(ROAD.kmh(full) > highest, "%s is over every limit at full speed" % car.id)


func _test_pedal_input() -> void:
	var game := _new_game(false)
	var pedal := game.hud.drive.brake_pedal
	var player := game.world.player
	await process_frame
	_check(pedal.visible, "The pedal shows while driving")
	var on_pedal := pedal.get_global_rect().get_center()
	var start_x := player.target_x
	_touch(0, on_pedal, true)
	_check(player.is_braking(), "Touching the pedal brakes")
	_drag(0, on_pedal + Vector2(30, 0), Vector2(30, 0))
	_check(is_equal_approx(player.target_x, start_x), "A finger on the pedal never steers")
	_touch(1, Vector2(300, 400), true)
	_drag(1, Vector2(330, 400), Vector2(30, 0))
	_check(is_equal_approx(player.target_x, start_x + 30.0), "Another finger steers while braking")
	_touch(0, on_pedal, false)
	_check(not player.is_braking(), "Lifting the finger releases the brake")
	_drag(1, Vector2(340, 400), Vector2(10, 0))
	_check(is_equal_approx(player.target_x, start_x + 40.0), "The steering finger keeps steering")
	_touch(1, Vector2(340, 400), false)
	_mouse(on_pedal, true)
	_check(player.is_braking(), "A mouse click on the pedal brakes")
	var motion := InputEventMouseMotion.new()
	motion.position = on_pedal + Vector2(20, 0)
	motion.relative = Vector2(20, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_check(is_equal_approx(player.target_x, start_x + 40.0), "Holding the pedal with the mouse")
	_mouse(on_pedal, false)
	_check(not player.is_braking(), "Releasing the mouse releases the brake")
	_touch(0, on_pedal, true)
	game.pause_run()
	_check(not pedal.visible and not pedal.held, "Pause hides and releases the pedal")
	_touch(0, on_pedal, false)
	game.free()


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	root.push_input(touch, true)


func _drag(index: int, at: Vector2, relative: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = at
	drag.relative = relative
	root.push_input(drag, true)


func _mouse(at: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = pressed
	root.push_input(click, true)


## cameras: keep speed cameras on; everything else that spawns is off.
func _new_game(cameras_on: bool) -> CruiseGame:
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
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	var night := game.get_node("World/Night") as NightView
	night.settings = night.settings.duplicate() as NightSettings
	night.settings.start_metres = 1.0e9
	var taxi := game.get_node("World/Taxi") as TaxiController
	taxi.settings = taxi.settings.duplicate() as TaxiSettings
	taxi.settings.first_order_metres = 1.0e9
	if not cameras_on:
		var controller := game.get_node("World/Cameras") as SpeedCameraController
		controller.settings = controller.settings.duplicate() as SpeedCameraSettings
		controller.settings.first_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _drive_steps(game: CruiseGame, steps: int) -> void:
	for _step in range(steps):
		game.advance(STEP)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

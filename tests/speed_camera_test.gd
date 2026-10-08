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
	_test_fines()
	_test_clean_pass()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: speed cameras, fines, clean passes, and dashboard layout (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_fines() -> void:
	var game := _new_game(true)
	var cameras := game.world.cameras
	_drive(game, CAMERAS.first_metres - 5.0)
	_check(cameras.cameras.is_empty(), "No camera before 400 m")
	_drive(game, 10.0)
	_check(cameras.cameras.size() == 1, "A camera appears after 400 m")
	var camera := cameras.cameras[0]
	var limit := camera.limit_kmh
	_check(CAMERAS.limits_kmh.has(limit), "The camera uses a configured limit")
	_check(
		game.hud.drive.pickup_label.text == "Camera: %d km/h limit! Brake" % limit,
		"A warning names the limit"
	)
	var speedometer := game.hud.drive.speedometer
	_check(speedometer.limit_kmh == limit, "The speedometer shows the limit sign")
	_check(speedometer.is_over_limit(), "Full speed reads over the limit")
	_check(camera.position.y < game.world.player.position.y - 600.0, "Time to brake")
	_check(
		camera.gantry.z_index + cameras.z_index > game.world.traffic.z_index,
		"The gantry passes over the cars"
	)
	_check(cameras.z_index < game.world.traffic.z_index, "The painted limit lies under the cars")
	game.score = 100
	_drive_until_passed(game, camera)
	var fine := CAMERAS.fine_for(60, limit)
	_check(fine == 15 + 60 - limit, "Fines grow with the speed over the limit")
	_check(game.score == 100 - fine, "Passing under too fast costs the fine")
	_check(camera.is_flashing(), "The camera flashes")
	_check(
		game.hud.drive.pickup_label.text == "Speeding fine!  −%d pts" % fine, "The fine is shown"
	)
	_check(game.pickup_feedback.camera_sound.playing, "The shutter clicks")
	_check(speedometer.limit_kmh == 0, "The limit sign clears after the camera")
	_drive(game, 30.0)
	_check(game.score == 100 - fine, "A camera fines once")
	_check(not camera.is_flashing(), "The flash fades with travel")
	var spawned_at := -1.0
	while spawned_at < 0.0 and game.distance_metres < 2000.0:
		_drive_steps(game, 1)
		if cameras.cameras.size() == 1 and cameras.cameras[0] != camera:
			spawned_at = game.distance_metres
		elif cameras.cameras.size() > 1:
			_check(false, "One camera at a time")
	var gap := spawned_at - CAMERAS.first_metres
	_check(gap >= CAMERAS.spawn_metres_min - 1.0, "Cameras are spaced out (%d m)" % gap)
	_check(gap <= CAMERAS.spawn_metres_max + 20.0, "Cameras keep coming (%d m)" % gap)
	game.score = 0
	_drive_until_passed(game, cameras.cameras[0])
	_check(game.score == 0, "Fines never take points below zero")
	_check(not game.is_game_over, "Fines never end the drive")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(cameras.cameras.is_empty() and cameras.active_limit() == 0, "Restart clears cameras")
	game.free()


func _test_clean_pass() -> void:
	var game := _new_game(true)
	var cameras := game.world.cameras
	_drive(game, CAMERAS.first_metres + 5.0)
	var camera := cameras.cameras[0]
	game.score = 50
	game.world.set_braking(true)
	_drive_steps(game, 30)
	_check(not game.hud.drive.speedometer.is_over_limit(), "Braked speed is under the limit")
	_drive_until_passed(game, camera)
	_check(game.score == 50, "Braking under the limit avoids the fine")
	_check(not camera.is_flashing(), "No flash when slow")
	_check(game.hud.drive.pickup_label.text == "Under the limit, no fine", "A clean pass is shown")
	game.free()


func _test_layout(locale: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language(locale)
	var drive := game.hud.drive
	_check(not drive.brake_pedal.visible, "The pedal is hidden in menus: " + locale)
	game.start_run()
	game.world.player.set_physics_process(false)
	drive.set_dashboard(
		{"fuel": 0.5, "fuel_low": false, "speed_kmh": 72, "limit_kmh": 40, "ride_metres": 450}
	)
	await process_frame
	var screen := Rect2(0, 0, 432, 768)
	var shown: Array[Control] = [
		drive.speedometer, drive.brake_pedal, drive.ride_chip, drive.fuel_gauge
	]
	var others: Array[Control] = [
		drive.distance_label,
		drive.score_label,
		drive.best_label,
		drive.pause_button,
		drive.horn_button,
		drive.power_up_bar,
		drive.title
	]
	for index in range(shown.size()):
		var rect := shown[index].get_global_rect()
		_check(shown[index].visible, "%s shows while driving" % shown[index].name)
		_check(screen.encloses(rect), "%s is on screen: %s" % [shown[index].name, locale])
		for other in others + shown.slice(index + 1):
			_check(
				not rect.intersects(other.get_global_rect()),
				"%s overlaps nothing (%s): %s" % [shown[index].name, other.name, locale]
			)
	_check(drive.brake_pedal.size.x >= 48 and drive.brake_pedal.size.y >= 48, "Pedal touch size")
	var gauge := drive.fuel_gauge
	_check(gauge.label_width() + 50.0 <= gauge.size.x, "The fuel label fits: " + locale)
	var font := drive.ride_chip.get_theme_default_font()
	var ride_width := (
		font.get_string_size(drive.ride_chip.text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	)
	_check(ride_width <= drive.ride_chip.size.x - 60.0, "The ride text fits: " + locale)
	for key in ["brake", "kmh"]:
		var size := 13 if key == "brake" else 11
		var width := font.get_string_size(tr(key), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_check(width <= 66.0, "%s fits: %s" % [key, locale])
	var popup := drive.pickup_label
	var popup_font := popup.get_theme_font("font")
	var popup_size := popup.get_theme_font_size("font_size")
	var messages := {
		"camera_ahead": [50],
		"camera_clean": [],
		"hazard_camera": [99],
		"taxi_call": [],
		"taxi_aboard": [450],
		"taxi_paid": [100],
		"taxi_missed": []
	}
	for key: String in messages:
		var values: Array = messages[key]
		var text := tr(key) % values if not values.is_empty() else tr(key)
		var width := popup_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, popup_size).x
		_check(width <= popup.size.x, "%s fits the popup: %s (%d)" % [key, locale, width])
	view.free()


func _drive_until_passed(game: CruiseGame, camera: SpeedCamera) -> void:
	var guard := 0
	while not camera.is_passed and guard < 2000 and not game.is_game_over:
		_drive_steps(game, 1)
		guard += 1


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


func _drive(game: CruiseGame, metres: float) -> void:
	var start := game.distance_metres
	while game.distance_metres - start < metres and not game.is_game_over:
		game.advance(STEP)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

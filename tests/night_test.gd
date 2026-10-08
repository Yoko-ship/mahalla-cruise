extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const NIGHT: NightSettings = preload("res://src/night/default_night.tres")
const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_nightfall()
	_test_bonus()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: nightfall, headlights, night bonus, and restart (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_nightfall() -> void:
	var game := _new_game()
	var night := game.world.night
	_drive_to(game, NIGHT.start_metres - 10.0)
	_check(not night.visible and night.amount == 0.0, "Daytime until 1,200 m")
	_drive_to(game, NIGHT.start_metres + NIGHT.dusk_metres * 0.5)
	_check(night.visible and night.amount > 0.4 and night.amount < 0.6, "Dusk darkens gradually")
	_check(game.hud.drive.pickup_label.text != "Night drive: points +50%", "No bonus at dusk")
	_drive_to(game, NIGHT.start_metres + NIGHT.dusk_metres + 1.0)
	_check(night.amount == 1.0, "Fully dark after dusk")
	_check(game.hud.drive.pickup_label.text == "Night drive: points +50%", "Nightfall is announced")
	var shade := night.material as ShaderMaterial
	_check(
		is_equal_approx(float(shade.get_shader_parameter("darkness")), NIGHT.darkness),
		"Night uses its configured darkness"
	)
	_check(
		shade.get_shader_parameter("car") == game.world.player.position,
		"Headlights follow the player"
	)
	_check(night.z_index > game.world.traffic.z_index, "Night shades the cars too")
	game.hud.drive.dismiss_text()
	_drive_to(game, game.distance_metres + 50.0)
	_check(not game.hud.drive.pickup_label.visible, "Nightfall is announced once")
	game.world.traffic.contacted.emit()
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(not night.visible and night.amount == 0.0, "Every drive starts in daylight")
	game.free()


func _test_bonus() -> void:
	var game := _new_game()
	var night := game.world.night
	_check(night.bonus(10) == 10, "No bonus by day")
	_drive_to(game, NIGHT.start_metres + NIGHT.dusk_metres + 1.0)
	_check(night.bonus(10) == 15 and night.bonus(1) == 2, "Night adds 50%, rounded up")
	var note := _add_note(game)
	var value := note.points
	_drive(game, 1.0)
	_check(game.score == night.bonus(value), "Night money pays the bonus")
	var before := game.score
	_add_car(game, game.world.player.position.x - 46.0, 420.0)
	_drive(game, 40.0)
	_check(game.score == before + 5, "Night close calls pay the bonus (3 → 5)")
	game.world.pickups.effects.activate("double")
	before = game.score
	note = _add_note(game)
	_drive(game, 1.0)
	_check(game.score == before + night.bonus(note.points * 2), "Double points and night stack")
	game.free()


func _add_note(game: CruiseGame) -> MoneyPickup:
	var note := MONEY_SCENE.instantiate() as MoneyPickup
	note.position = game.world.player.position - Vector2(0, 60)
	game.world.pickups.add_child(note)
	var definition := game.pickup_settings.select_note(false, 0.0)
	var points := game.pickup_settings.points_for(definition)
	note.configure(definition, points, game.pickup_settings.collision_half_size)
	game.world.pickups.items.append(note)
	return note


func _add_car(game: CruiseGame, x: float, y: float) -> void:
	var car := CAR_SCENE.instantiate() as TrafficCar
	car.position = Vector2(x, y)
	game.world.traffic.add_child(car)
	car.configure(game.traffic_settings.collision_half_size, Color.WHITE)
	game.world.traffic.vehicles.append(car)


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
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
	var fuel := game.get_node("World/Fuel") as FuelController
	fuel.settings = fuel.settings.duplicate() as FuelSettings
	fuel.settings.tank_metres = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _drive_to(game: CruiseGame, metres: float) -> void:
	_drive(game, metres - game.distance_metres)


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

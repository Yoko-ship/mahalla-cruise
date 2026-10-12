extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const MONEY_SCENE: PackedScene = preload("res://src/pickups/money_pickup.tscn")
const HAZARD_SCENE: PackedScene = preload("res://src/hazards/road_hazard.tscn")
const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const STEP: float = 1.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_money_popup()
	_test_close_call_popup()
	_test_hazard_shake()
	_test_crash()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: point popups, crash puff, street shake, and reset (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_money_popup() -> void:
	var game := _new_game()
	var effects := game.world.effects
	var note := MONEY_SCENE.instantiate() as MoneyPickup
	note.position = game.world.player.position - Vector2(0, 50)
	game.world.pickups.add_child(note)
	var definition := game.pickup_settings.som_notes[2]
	note.configure(definition, 10, game.pickup_settings.collision_half_size)
	game.world.pickups.items.append(note)
	for _frame in range(10):
		game.advance(STEP)
	_check(effects.popups.size() == 1, "Collecting a note pops its points")
	_check(effects.popups[0].text == "+10", "The popup shows what it paid")
	_check(absf(effects.popups[0].spot.x - note.position.x) < 1.0, "Where the note was")
	_check(effects.z_index > game.world.night.z_index, "Popups show over the night")
	effects._process(RoadEffects.POPUP_SECONDS * 0.5)
	_check(effects.popups.size() == 1 and effects.is_processing(), "It rises for a moment")
	effects._process(RoadEffects.POPUP_SECONDS)
	_check(effects.popups.is_empty() and not effects.is_processing(), "Then it is gone")
	game.free()


func _test_close_call_popup() -> void:
	var game := _new_game()
	var player := game.world.player
	_add_car(game, player.position.x - 46.0, 420.0)
	for _frame in range(90):
		game.advance(STEP)
	_check(game.near_misses == 1, "A close call")
	var popup: Dictionary = game.world.effects.popups.back()
	_check(popup.text == "+3" and popup.colour == RoadEffects.CLOSE, "Close calls pop in blue")
	game.free()


func _test_hazard_shake() -> void:
	var game := _new_game()
	game.score = 50
	var hazard := HAZARD_SCENE.instantiate() as RoadHazard
	hazard.position = game.world.player.position - Vector2(0, 50)
	game.world.hazards.add_child(hazard)
	hazard.configure("pothole", game.world.hazards.settings.half_size("pothole"))
	game.world.hazards.hazards.append(hazard)
	for _frame in range(10):
		game.advance(STEP)
	_check(game.score == 40, "The pothole costs points")
	var popup: Dictionary = game.world.effects.popups.back()
	_check(popup.text == "−10" and popup.colour == RoadEffects.LOSS, "Penalties pop in red")
	_check(game.world._shake_seconds > 0.0, "A bump shakes the street")
	game.world._process(0.05)
	_check(game.world.position.length() <= 3.0 * 1.5, "Gently")
	game.world._process(1.0)
	_check(game.world.position == Vector2.ZERO, "And settles back")
	game.free()


func _test_crash() -> void:
	var game := _new_game()
	game.world.effects.pop(Vector2(200, 300), "+5")
	_add_car(game, game.world.player.position.x, game.world.player.position.y - 90.0)
	for _frame in range(30):
		game.advance(STEP)
		if game.is_game_over:
			break
	_check(game.is_game_over, "The crash ends the drive")
	_check(game.world.effects.puffs.size() == 1, "Dust puffs where the cars met")
	game.world._process(0.02)
	_check(game.world.position != Vector2.ZERO, "The street shakes")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(game.world.effects.popups.is_empty(), "A new drive clears popups")
	_check(game.world.effects.puffs.is_empty() and game.world.position == Vector2.ZERO, "And shake")
	game.free()


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
	var pickups := game.get_node("World/Pickups") as PickupController
	pickups.power_up_settings = pickups.power_up_settings.duplicate() as PowerUpSettings
	pickups.power_up_settings.first_spawn_metres = 1.0e9
	var hazards := game.get_node("World/Hazards") as HazardController
	hazards.settings = hazards.settings.duplicate() as HazardSettings
	hazards.settings.first_metres = 1.0e9
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

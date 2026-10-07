extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const CAR_SCENE: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const TRAFFIC: TrafficSettings = preload("res://src/traffic/default_traffic.tres")
# Player starts at x=216 with a 40-pixel-wide box (196..236).
const CLOSE_LEFT: float = 170.0  # 6-pixel gap
const CLOSE_RIGHT: float = 262.0  # 6-pixel gap
const FAR_LEFT: float = 146.0  # 30-pixel gap

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_close_and_far_passes()
	_test_combo()
	_test_combo_window()
	_test_crash_priority_and_restart()
	_test_pause_and_long_frames()
	_test_close_call_sound()
	_check(TRAFFIC.near_miss_gap == 10.0 and TRAFFIC.near_miss_points == 3, "Defaults unchanged")
	_check(TRAFFIC.near_miss_max_combo == 5, "Combo cap default unchanged")
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: near-miss detection, combo scoring, crash priority, and reset (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_close_and_far_passes() -> void:
	var game := _new_game()
	_add_car(game, CLOSE_LEFT, 400.0)
	_drive(game, 4.0)
	_check(game.near_misses == 1 and game.score == 3, "A close pass awards near-miss points")
	_check(game.hud.pickup_label.text == "Close call!  +3 pts", "A close pass shows feedback")
	_check(game.traffic.near_miss_combo == 1, "The first near miss starts the combo")
	_check(not game.is_game_over, "A near miss is not a crash")
	game.free()
	game = _new_game()
	_add_car(game, FAR_LEFT, 400.0)
	_drive(game, 4.0)
	_check(game.near_misses == 0 and game.score == 0, "A wide pass earns nothing")
	game.free()
	game = _new_game()
	_add_car(game, CLOSE_LEFT, 400.0)
	game.player.position.x = 250.0
	_drive(game, 4.0)
	_check(game.near_misses == 0, "Only the gap while level with the player counts")
	game.free()


func _test_combo() -> void:
	var game := _new_game()
	for index in range(6):
		_add_car(game, CLOSE_LEFT if index % 2 == 0 else CLOSE_RIGHT, 420.0 - index * 70.0)
	_drive(game, 6.0)
	_check(game.near_misses == 6, "Each close car counts once")
	_check(game.score == 3 + 6 + 9 + 12 + 15 + 15, "Combo multiplies points up to its cap")
	_check(game.traffic.near_miss_combo == 5, "Combo stops at the configured maximum")
	_check(
		game.hud.pickup_label.text == "Close call ×5!  +15 pts", "Combo feedback shows the chain"
	)
	game.free()


func _test_combo_window() -> void:
	var game := _new_game()
	_add_car(game, CLOSE_LEFT, 500.0)
	_drive(game, 2.0)
	_check(game.score == 3, "First near miss before the window test")
	_drive(game, 8.0)
	_add_car(game, CLOSE_RIGHT, 500.0)
	_drive(game, 2.0)
	_check(game.score == 6 and game.traffic.near_miss_combo == 1, "A late near miss restarts combo")
	game.free()


func _test_crash_priority_and_restart() -> void:
	var game := _new_game()
	var bounds := game.player.collision_bounds()
	# The blocking car is processed after the passing car, so its crash ends the same frame.
	var blocker := _add_car(game, 216.0, bounds.position.y - 40.0)
	var passing := _add_car(game, CLOSE_LEFT, bounds.end.y + 35.0)
	game.advance(0.1)
	_check(game.is_game_over and blocker.has_contacted, "The blocking car ends the run")
	_check(passing.has_passed, "The other car still finished its pass")
	_check(game.score == 0 and game.near_misses == 0, "No near-miss points on the crash frame")
	game.restart_run()
	game.player.set_physics_process(false)
	_add_car(game, CLOSE_LEFT, 400.0)
	_drive(game, 4.0)
	_check(game.near_misses == 1, "Near misses work after restart")
	_crash(game)
	_check(
		game.hud.game_over_panel.money_result.text.contains("Close calls × 1"),
		"Results count close calls"
	)
	_check(game.progress.wallet == 3, "Near-miss points pay into the wallet")
	game.restart_run()
	game.player.set_physics_process(false)
	_check(game.near_misses == 0 and game.score == 0, "Restart clears near misses")
	_check(
		not game.hud.game_over_panel.money_result.text.contains("Close"),
		"Zero close calls stay unlisted"
	)
	_check(game.traffic.near_miss_combo == 0, "Restart clears the combo")
	game.free()


func _test_pause_and_long_frames() -> void:
	var game := _new_game()
	var car := _add_car(game, CLOSE_LEFT, 400.0)
	game.pause_run()
	_drive(game, 4.0)
	_check(car.position.y == 400.0 and game.near_misses == 0, "Paused traffic never scores")
	game.resume_run()
	game.advance(5.0)
	_check(game.near_misses == 1, "A long frame cannot skip a close pass")
	game.free()


func _test_close_call_sound() -> void:
	var game := _new_game()
	var sound := game.pickup_feedback.close_call_sound
	_check(
		sound.stream != game.pickup_feedback.som_sound.stream, "Close calls have their own sound"
	)
	_add_car(game, CLOSE_LEFT, 420.0)
	_add_car(game, CLOSE_RIGHT, 350.0)
	_drive(game, 4.0)
	_check(sound.playing, "A close call plays the whoosh")
	_check(is_equal_approx(sound.pitch_scale, 1.06), "A higher combo raises the whoosh pitch")
	game.pickup_feedback.stop()
	game.hud.sound_toggled.emit(false)
	_add_car(game, CLOSE_LEFT, 420.0)
	_drive(game, 4.0)
	_check(game.near_misses == 3 and not sound.playing, "Muted close calls stay silent")
	game.hud.sound_toggled.emit(true)
	game.pickup_feedback.play_close_call(1)
	game.pickup_feedback.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not sound.playing, "Losing focus stops the whoosh")
	game.free()


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 100000.0
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	return game


func _add_car(game: CruiseGame, x: float, y: float) -> TrafficCar:
	var car := CAR_SCENE.instantiate() as TrafficCar
	car.position = Vector2(x, y)
	game.traffic.add_child(car)
	car.configure(game.traffic_settings.collision_half_size, Color.WHITE)
	game.traffic.vehicles.append(car)
	return car


func _drive(game: CruiseGame, seconds: float) -> void:
	for _step in range(roundi(seconds * 30.0)):
		game.advance(1.0 / 30.0)


func _crash(game: CruiseGame) -> void:
	_add_car(game, game.player.position.x, game.player.position.y - 90.0)
	_drive(game, 1.0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

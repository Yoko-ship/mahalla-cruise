extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://best_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game := _new_game()
	var before_collection := FileAccess.get_file_as_string(_path)
	_check(game.hud.drive.best_label.text == "Best: 0", "First launch displays zero best")
	game.advance(game.pickup_settings.first_spawn_distance / game.road_settings.scroll_speed)
	var item: MoneyPickup = game.world.pickups.items.front()
	var expected := item.points
	game.world.player.position.x = item.position.x
	game.advance(3.5)
	_check(game.score == expected and expected > 0, "Collect an actual note for the run")
	_check(
		FileAccess.get_file_as_string(_path) == before_collection,
		"Collection performs no disk write during driving"
	)
	_crash(game)
	_check(game.is_game_over, "Actual traffic collision ends the scored run")
	_check(game.progress.best_score == expected, "Crash records the final score")
	_check(
		game.hud.game_over_panel.best_result.text == "New best! %d" % expected,
		"Record gets a celebration"
	)
	_check(game.hud.drive.best_label.text == "Best: %d" % expected, "HUD displays the saved record")
	var saved := FileAccess.get_file_as_string(_path)
	game.advance(50.0)
	_check(FileAccess.get_file_as_string(_path) == saved, "Frozen frames never rewrite the record")
	game.hud.game_over_panel.restart_button.pressed.emit()
	game.world.player.set_physics_process(false)
	_check(
		game.score == 0 and game.progress.best_score == expected, "Restart retains only the best"
	)
	_check(
		game.hud.game_over_panel.best_result.text == "Best: %d" % expected,
		"Restart clears the celebration"
	)
	game.free()
	game = _new_game()
	_check(game.progress.best_score == expected, "Reopening the scene loads persistent data")
	_check(game.hud.drive.best_label.text == "Best: %d" % expected, "Reopened HUD shows the record")
	game.score = expected
	_crash(game)
	_check(
		game.hud.game_over_panel.best_result.text == "Best: %d" % expected,
		"Ties do not show New best"
	)
	game.restart_run()
	game.world.player.set_physics_process(false)
	_crash(game)
	_check(game.progress.best_score == expected, "A zero-score run retains the best")
	game.free()
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: best-score collision, HUD, restart, and reopen integration (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.spawn_distance = 10000.0
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _crash(game: CruiseGame) -> void:
	var settings := game.traffic_settings.duplicate() as TrafficSettings
	settings.first_spawn_distance = 1.0
	game.world.traffic.configure(game.road_settings, settings)
	game.world.traffic.advance(1.0, game.world.player.collision_bounds())
	var car: TrafficCar = game.world.traffic.vehicles.front()
	car.position = game.world.player.position - Vector2(0, 90)
	game.advance(0.5)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

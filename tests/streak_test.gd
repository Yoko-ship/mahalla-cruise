extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const DAILY_SCENE: PackedScene = preload("res://src/daily/daily_tasks.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_dates()
	_test_streak_rules()
	await _test_menu_and_results()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: daily streak days, rewards, cap, menu row, and results (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_dates() -> void:
	_check(DailyTasks._previous_day("2026-10-07") == "2026-10-06", "Previous day")
	_check(DailyTasks._previous_day("2026-03-01") == "2026-02-28", "Across a month")
	_check(DailyTasks._previous_day("2027-01-01") == "2026-12-31", "Across a year")
	_check(DailyTasks._previous_day("2028-03-01") == "2028-02-29", "Across a leap day")


func _test_streak_rules() -> void:
	var daily := DAILY_SCENE.instantiate() as DailyTasks
	root.add_child(daily)
	daily.load_state({}, "2026-10-07")
	_check(daily.state.streak == 1 and not daily.state.streak_paid, "A first day starts the streak")
	var rewards := daily.record_run(_run_stats(), "2026-10-07")
	_check(rewards == [20], "The first drive of day one pays 20")
	_check(daily.record_run(_run_stats(), "2026-10-07").is_empty(), "The streak pays once a day")
	var saved: Dictionary = daily.state.duplicate(true)
	saved.streak = 3
	daily.load_state(saved, "2026-10-08")
	_check(daily.state.streak == 4, "Driving yesterday continues the streak")
	_check(daily.record_run(_run_stats(), "2026-10-08") == [80], "Day four pays 80")
	saved = daily.state.duplicate(true)
	saved.streak = 12
	daily.load_state(saved, "2026-10-09")
	_check(daily.streak_reward() == 140, "Rewards stop growing after seven days")
	saved = daily.state.duplicate(true)
	saved.streak_paid = false
	daily.load_state(saved, "2026-10-10")
	_check(daily.state.streak == 1, "A day without a finished drive breaks the streak")
	saved = daily.state.duplicate(true)
	saved.streak_paid = true
	daily.load_state(saved, "2026-10-12")
	_check(daily.state.streak == 1, "Skipping a day restarts at day one")
	saved.streak = "lots"
	daily.load_state(saved, "2026-10-13")
	_check(daily.state.streak == 1, "A damaged streak restarts safely")
	daily.free()


func _test_menu_and_results() -> void:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	var menu := game.hud.daily_menu
	_check(menu.rows.get_child_count() == 4, "Tasks list three tasks and the streak")
	var row := menu.rows.get_child(3)
	var text := (row.get_node("Layout/Text") as Label).text
	_check(text == "Day 1 streak: drive once today", "The streak row names the day")
	_check(not (row.get_node("Layout/Status/Count") as Label).visible, "The streak has no counter")
	_check((row.get_node("Layout/Status/Reward") as Label).text == "+20 pts", "Shows its reward")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.world.traffic.contacted.emit()
	_check(game.progress.wallet >= 20, "The streak reward reaches the wallet")
	var wallet := game.hud.game_over_panel.wallet_result.text
	_check(wallet.contains("+20 pts"), "Results list the streak reward")
	row = menu.rows.get_child(3)
	_check((row.get_node("Layout/Status/Reward") as Label).text == "Done ✓", "Marked done")
	game.free()


func _run_stats() -> Dictionary:
	return {"notes": 0, "close_calls": 0, "metres": 0, "score": 0, "runs": 1}


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

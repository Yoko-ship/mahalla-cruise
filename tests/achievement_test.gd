extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const ACHIEVEMENTS_SCENE: PackedScene = preload("res://src/achievements/achievements.tscn")
const CATALOGUE: AchievementCatalogue = preload("res://src/achievements/default_achievements.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://achievement_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_catalogue()
	_test_progress_and_rewards()
	_test_storage()
	await _test_game_flow()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: lifetime achievements, one-time rewards, saving, and screen (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_catalogue() -> void:
	var ids := {}
	var kinds := {}
	var ascending := true
	var last := {}
	for achievement in CATALOGUE.achievements:
		ids[achievement.id] = true
		kinds[achievement.kind] = true
		ascending = ascending and achievement.target > int(last.get(achievement.kind, 0))
		last[achievement.kind] = achievement.target
		_check(achievement.reward > 0, "Every achievement pays: " + achievement.id)
	_check(ids.size() == CATALOGUE.achievements.size() and ids.size() == 16, "16 unique ids")
	_check(kinds.size() == AchievementDefinition.Kind.size(), "Every kind has goals")
	_check(ascending, "Within a kind, targets rise")


func _test_progress_and_rewards() -> void:
	var achievements := _achievements()
	achievements.load_state({})
	var rewards := achievements.record_run(_summary(60, 10, 1100, 250, 2))
	_check(rewards == [150], "A 1,100 m drive unlocks the 1,000 m goal only")
	rewards = achievements.record_run(_summary(60, 20, 900, 320, 3))
	_check(rewards == [150, 150, 200, 200], "Totals add up over drives; bests keep the highest")
	_check(achievements.state.stats.metres == 2000, "Lifetime metres")
	_check(achievements.state.stats.best_metres == 1100, "Best single drive")
	_check(achievements.state.stats.runs == 2, "Drives counted")
	rewards = achievements.record_run(_summary(0, 0, 3100, 0, 0))
	_check(rewards == [150, 500], "5 km in total and a 2,500 m drive unlock together")
	_check(achievements.record_run(_summary(0, 0, 10, 0, 0)).is_empty(), "Goals never pay twice")
	var entries := achievements.entries()
	_check(entries.size() == AchievementDefinition.Kind.size(), "One row per kind")
	var distance := entries[0]
	_check(
		distance.text_key == "ach_distance" and distance.target == 25 and distance.progress == 5,
		"Lifetime distance shows the next goal in km"
	)
	var notes := entries[1]
	_check(notes.target == 500 and notes.progress == 120 and not notes.done, "Next notes goal")
	achievements.state.stats.best_score = 5000
	achievements.record_run(_summary(0, 0, 0, 0, 0))
	var score := achievements.entries()[6]
	_check(score.done and score.target == 1000, "When every goal is done the last one shows done")
	achievements.load_state(
		{"stats": {"metres": -5, "notes": "x", "runs": 4.0}, "done": ["runs_10", "nope", 3]}
	)
	_check(achievements.state.stats == {"runs": 4}, "Damaged stats fall back")
	_check(achievements.state.done == ["runs_10"], "Only known ids stay unlocked")
	achievements.free()


func _test_storage() -> void:
	_cleanup()
	var store := _store()
	var achievements := _achievements()
	achievements.load_state(store.achievements)
	var rewards := achievements.record_run(_summary(120, 0, 500, 40, 0))
	store.stage_achievements(achievements.state, rewards)
	_check(FileAccess.get_file_as_string(_path).is_empty(), "Staging alone does not write")
	store.complete_run(40)
	_check(store.wallet == 40 + 150, "Achievement rewards reach the wallet with the run")
	var reopened := _store()
	_check(reopened.wallet == 190, "The wallet survives relaunch")
	achievements.load_state(reopened.achievements)
	_check(achievements.state.done == ["notes_100"], "Unlocked goals survive relaunch")
	_check(achievements.state.stats.notes == 120, "Lifetime totals survive relaunch")
	_write('{"version": 1, "stats": {"best_score": 9}, "achievements": [1, 2]}')
	store.free()
	store = _store()
	_check(store.best_score == 9 and store.achievements.is_empty(), "A damaged section is ignored")
	_write('{"version": 1, "stats": {"best_score": 9}, "achievements": {"future": 1}}')
	store.free()
	store = _store()
	achievements.load_state(store.achievements)
	var none: Array[int] = []
	store.stage_achievements(achievements.state, none)
	store.complete_run(1)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
	_check(saved.achievements.get("future") == 1, "Unknown achievement fields are kept")
	store.free()
	reopened.free()
	achievements.free()


func _test_game_flow() -> void:
	_cleanup()
	var game := _new_game(_path)
	game.daily.state.streak_paid = true
	game.start_run()
	game.world.player.set_physics_process(false)
	game.som_collected = 100
	game.score = 30
	game.distance_metres = 400.0
	var wallet := game.progress.wallet
	game.world.traffic.contacted.emit()
	_check(game.achievements.state.done.has("notes_100"), "A finished drive unlocks goals")
	_check(game.progress.wallet >= wallet + 30 + 150, "Rewards are paid at the end of the drive")
	var text := game.hud.game_over_panel.wallet_result.text
	_check(text.contains("Achievement! +150 pts"), "Results announce the achievement")
	game.restart_run()
	_check(not game.hud.game_over_panel.wallet_result.text.contains("Achievement"), "Reset")
	game.free()
	var reopened := _new_game(_path)
	_check(reopened.achievements.state.done.has("notes_100"), "Achievements survive relaunch")
	await _click(reopened.hud.menu.tasks_button)
	var menu := reopened.hud.daily_menu
	_check(menu.visible and not menu.showing_achievements, "Tasks open on the daily list")
	_check(menu.switch_button.text == "Achievements", "A button switches to achievements")
	await _click(menu.switch_button)
	_check(menu.showing_achievements and menu.title.text == "Achievements", "Achievements show")
	_check(menu.rows.get_child_count() == AchievementDefinition.Kind.size(), "One row per kind")
	var notes := menu.rows.get_child(1).get_node("Layout/Text") as Label
	_check(notes.text == "Collect 500 notes in total", "The next goal is shown with its target")
	var done := menu.rows.get_child(1).get_node("Layout/Status/Count") as Label
	_check(done.text == "100 / 500", "Progress counts toward the next goal")
	_check(menu.switch_button.text == "Daily tasks", "The button switches back")
	await _click(menu.back_button)
	await _click(reopened.hud.menu.tasks_button)
	_check(not menu.showing_achievements, "Tasks reopen on the daily list")
	reopened.free()


func _test_layout(locale: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language(locale)
	game.hud.menu.tasks_pressed.emit()
	game.hud.daily_menu.switch_button.pressed.emit()
	for _frame in range(3):
		await process_frame
	var card := game.hud.daily_menu.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Achievements fit: " + locale)
	for row in game.hud.daily_menu.rows.get_children():
		var status := row.get_node("Layout/Status") as Control
		_check(status.size.x <= (row as Control).size.x, "Row fits: " + locale)
	view.free()


func _summary(notes: int, close_calls: int, metres: int, score: int, refuels: int) -> Dictionary:
	return DailyTasks.summary(notes, close_calls, metres, score, refuels)


func _achievements() -> Achievements:
	var achievements := ACHIEVEMENTS_SCENE.instantiate() as Achievements
	root.add_child(achievements)
	return achievements


func _store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _new_game(path: String) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = path
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	return game


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _write(text: String) -> void:
	_cleanup()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

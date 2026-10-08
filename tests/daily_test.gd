extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const DAILY_SCENE: PackedScene = preload("res://src/daily/daily_tasks.tscn")
const CATALOGUE: DailyCatalogue = preload("res://src/daily/default_daily.tres")
const DAY: String = "2026-10-07"
const PICKED: Array[String] = ["notes_15", "distance_400", "runs_3"]

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://daily_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_catalogue_and_draw()
	_test_progress_and_rewards()
	_test_storage()
	await _test_game_flow()
	for locale in ProgressData.LANGUAGES:
		await _test_layout(locale)
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: daily task draw, progress, rewards, storage, and menu (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_catalogue_and_draw() -> void:
	var ids := {}
	var kinds := {}
	for task in CATALOGUE.tasks:
		ids[task.id] = true
		kinds[task.kind] = true
		_check(task.reward > 0 and task.target > 0, "Every task has a target and reward")
	_check(ids.size() == CATALOGUE.tasks.size() and ids.size() == 10, "Ten tasks with unique ids")
	_check(kinds.size() == DailyTaskDefinition.Kind.size(), "Every task kind is available")
	var daily := _daily()
	daily.load_state({}, DAY)
	var first: Array = daily.state.tasks.duplicate()
	var drawn_kinds := {}
	for id: String in first:
		drawn_kinds[CATALOGUE.find(id).kind] = true
	_check(first.size() == 3 and drawn_kinds.size() == 3, "Three tasks of different kinds")
	daily.load_state({}, DAY)
	_check(daily.state.tasks == first, "The same day always draws the same tasks")
	var sets := {}
	for day in range(1, 11):
		daily.load_state({}, "2026-11-%02d" % day)
		sets[str(daily.state.tasks)] = true
	_check(sets.size() >= 3, "Different days draw different tasks")
	daily.free()


func _test_progress_and_rewards() -> void:
	var daily := _daily()
	daily.load_state(_state(), DAY)
	_check(daily.state.tasks == PICKED, "A valid saved state is kept")
	var rewards := daily.record_run(_run_stats(10, 300), DAY)
	_check(rewards.is_empty(), "Unfinished tasks pay nothing")
	rewards = daily.record_run(_run_stats(6, 450), DAY)
	_check(rewards == [40, 50], "Notes add up over the day; distance needs one long run")
	_check(daily.state.progress.notes_15 == 15, "Progress is capped at the target")
	rewards = daily.record_run(_run_stats(30, 900), DAY)
	_check(rewards == [30], "Finished tasks never pay twice; the third drive pays")
	_check(daily.state.done.size() == 3, "All three tasks are done")
	var entries := daily.entries()
	_check(entries.size() == 3 and entries[0].done and entries[2].progress == 3, "Menu entries")
	daily.load_state(_state(), DAY)
	daily.record_run(_run_stats(0, 300), DAY)
	daily.record_run(_run_stats(0, 300), DAY)
	_check(daily.state.progress.distance_400 == 300, "Distance never adds across runs")
	rewards = daily.record_run(_run_stats(50, 999), "2026-10-08")
	_check(daily.state.day == "2026-10-08", "A new day starts new tasks")
	_check(
		daily.state.done.size() + 1 == rewards.size(),
		"After rollover only the new day's run counts, plus its streak bonus"
	)
	for broken: Dictionary in [
		{"day": DAY, "tasks": ["nope", "runs_3", "notes_15"], "progress": {}, "done": []},
		{"day": DAY, "tasks": PICKED, "progress": {"runs_3": -1}, "done": []},
		{"day": DAY, "tasks": ["runs_3"], "progress": {}, "done": []},
		{"day": DAY, "tasks": PICKED, "progress": [], "done": []},
	]:
		daily.load_state(broken, DAY)
		_check(daily.state.tasks.size() == 3 and daily.state.progress.is_empty(), "Damaged state")
	daily.free()


func _test_storage() -> void:
	_cleanup()
	var store := _store()
	var daily := _daily()
	daily.load_state(store.daily, DAY)
	daily.load_state(_state(), DAY)
	var rewards := daily.record_run(_run_stats(20, 100), DAY)
	store.stage_daily(daily.state, rewards)
	_check(FileAccess.get_file_as_string(_path).is_empty(), "Staging alone does not write")
	store.complete_run(25)
	_check(store.wallet == 25 + 40, "Run points and task rewards both reach the wallet")
	var reopened := _store()
	_check(reopened.wallet == 65, "Wallet with rewards survives relaunch")
	daily.load_state(reopened.daily, DAY)
	_check(daily.state.tasks == PICKED, "Saved tasks survive relaunch on the same day")
	_check(daily.state.progress.notes_15 == 15 and "notes_15" in daily.state.done, "And progress")
	_check(daily.record_run(_run_stats(20, 100), DAY).is_empty(), "Reloaded tasks never repay")
	_write('{"version": 1, "stats": {"best_score": 9}, "daily": {"day": "x", "future": 2}}')
	store.free()
	store = _store()
	_check(store.best_score == 9, "A damaged daily state never loses the record")
	daily.load_state(store.daily, DAY)
	var no_rewards: Array[int] = []
	store.stage_daily(daily.state, no_rewards)
	store.complete_run(1)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
	_check(saved.daily.get("future") == 2 and saved.daily.day == DAY, "Unknown daily fields kept")
	store.free()
	reopened.free()
	daily.free()


func _test_game_flow() -> void:
	_cleanup()
	var game := _new_game(_path)
	var today := DailyTasks.today()
	var state := _state()
	state.day = today
	game.daily.load_state(state)
	game.hud.set_daily(game.daily.entries())
	await _click(game.hud.menu.tasks_button)
	var menu := game.hud.daily_menu
	_check(menu.visible and not game.hud.menu.visible, "Tasks open from the start screen")
	_check(menu.rows.get_child_count() == 3, "Three task rows")
	var first := menu.rows.get_child(0).get_node("Layout/Text") as Label
	_check(first.text == "Collect 15 notes", "Task text is translated with its target")
	await _click(menu.back_button)
	_check(not menu.visible and game.hud.menu.visible, "Back returns to start")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.som_collected = 15
	game.score = 20
	game.distance_metres = 420.0
	game.world.traffic.contacted.emit()
	_check(game.progress.wallet == 20 + 40 + 50, "Finished tasks pay into the wallet")
	var wallet_text := game.hud.game_over_panel.wallet_result.text
	_check(wallet_text.contains("Task complete! +40 pts"), "Results announce completed tasks")
	_check(wallet_text.contains("Task complete! +50 pts"), "Each completed task is listed")
	var row := menu.rows.get_child(0).get_node("Layout/Status/Reward") as Label
	_check(row.text == "Done ✓", "The task menu marks finished tasks")
	game.restart_run()
	_check(not game.hud.game_over_panel.wallet_result.text.contains("Task"), "Results reset")
	game.free()
	var reopened := _new_game(_path)
	_check(reopened.daily.state.done.size() == 2, "Daily progress is restored after relaunch")
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
	await _settle()
	for button: Button in [game.hud.menu.garage_button, game.hud.menu.tasks_button]:
		var font := button.get_theme_font("font")
		var size := button.get_theme_font_size("font_size")
		var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_check(
			width <= button.size.x - 8.0, "Start action label fits: %s %s" % [locale, button.text]
		)
	game.hud.menu.tasks_pressed.emit()
	await _settle()
	var card := game.hud.daily_menu.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Tasks menu fits: " + locale)
	view.free()


func _daily() -> DailyTasks:
	var daily := DAILY_SCENE.instantiate() as DailyTasks
	root.add_child(daily)
	return daily


func _state() -> Dictionary:
	return {"day": DAY, "tasks": PICKED.duplicate(), "progress": {}, "done": []}


func _run_stats(notes: int, metres: int) -> Dictionary:
	return {"notes": notes, "close_calls": 0, "metres": metres, "score": 0, "runs": 1}


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


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


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

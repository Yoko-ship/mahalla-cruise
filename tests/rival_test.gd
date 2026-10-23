extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const RIVALS: RivalLadder = preload("res://src/rivals/default_rivals.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ladder()
	_test_rows()
	await _test_game_flow()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: mahalla rating, passing rewards, rows, and screen (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_ladder() -> void:
	_check(RIVALS.names.size() == RIVALS.scores.size(), "Every driver has a score")
	_check(RIVALS.rewards.size() == RIVALS.scores.size(), "Every driver has a reward")
	for index in range(1, RIVALS.scores.size()):
		_check(RIVALS.scores[index] > RIVALS.scores[index - 1], "Drivers are easiest first")
	_check(RIVALS.newly_passed(0, 30) == [0], "30 passes the first driver (25)")
	_check(RIVALS.newly_passed(30, 60).is_empty(), "A tie does not pass")
	_check(RIVALS.newly_passed(30, 101) == [1, 2], "One drive can pass several")
	_check(RIVALS.newly_passed(101, 90).is_empty(), "A lower score passes no one")
	_check(RIVALS.rank(0) == RIVALS.scores.size() + 1, "A new player starts last")
	_check(RIVALS.rank(8000) == 1, "Beating everyone is first place")
	_check(RIVALS.next_index(0) == 0 and RIVALS.next_index(8000) == -1, "Next driver ahead")


func _test_rows() -> void:
	var rows := RIVALS.entries(0)
	_check(rows.size() == 4 and rows.back().name == "", "A new player sees three drivers ahead")
	_check(_places(rows) == [13, 14, 15, 16], "Places count down to the player")
	rows = RIVALS.entries(400)
	_check(rows.size() == 6, "Three ahead, the player, and two passed")
	_check(_places(rows) == [7, 8, 9, 10, 11, 12], "The player sits between them")
	_check(rows[3].name == "" and rows[3].progress == 400, "The player row shows the best")
	_check(rows[2].name == "Rustam aka" and not rows[2].done, "The next driver is just above")
	_check(rows[4].name == "Shahzoda" and rows[4].done, "Passed drivers are below")
	rows = RIVALS.entries(8000)
	_check(rows.front().name == "" and rows.front().place == 1, "Top of the mahalla")
	_check(
		rows.size() == 6 and rows.all(func(row: Dictionary) -> bool: return row.place <= 6),
		"Top six"
	)


func _test_game_flow() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language("en")
	game.daily.state.streak_paid = true
	game.start_run()
	game.world.player.set_physics_process(false)
	game.score = 120
	var wallet := game.progress.wallet
	game.world.traffic.contacted.emit()
	var text := game.hud.game_over_panel.wallet_result.text
	_check(text.contains("You passed 3 neighbours! +90 pts"), "Several passes share one line")
	_check(text.contains("Next up: Dilnoza opa · 160"), "Results name the next driver")
	_check(game.progress.wallet >= wallet + 120 + 90, "Passing pays each reward")
	wallet = game.progress.wallet
	game.restart_run()
	game.world.player.set_physics_process(false)
	game.score = 110
	game.world.traffic.contacted.emit()
	text = game.hud.game_over_panel.wallet_result.text
	_check(not text.contains("You passed"), "A driver pays only once")
	_check(game.progress.wallet <= wallet + 110 + 40, "No reward for drivers already passed")
	game.restart_run()
	game.world.player.set_physics_process(false)
	game.score = 161
	game.world.traffic.contacted.emit()
	text = game.hud.game_over_panel.wallet_result.text
	_check(text.contains("You passed Dilnoza opa! +50 pts"), "A single pass names the driver")
	game.open_garage()
	game.hud.garage_menu.close()
	game.hud.menu.tasks_button.pressed.emit()
	var menu := game.hud.daily_menu
	menu.switch_button.pressed.emit()
	menu.switch_button.pressed.emit()
	for _frame in range(3):
		await process_frame
	_check(menu.title.text == "Mahalla rating", "The tasks screen has the rating")
	var you := menu.rows.get_child(3).get_node("Layout/Text") as Label
	_check(you.text == "12. You · 161 pts", "The player's place and best")
	var reward := menu.rows.get_child(4).get_node("Layout/Status/Reward") as Label
	_check(reward.text == "Passed", "Passed drivers are marked")
	var ahead := menu.rows.get_child(2).get_node("Layout/Status/Reward") as Label
	_check(ahead.text == "+70 pts", "Drivers ahead show their reward")
	for locale in ProgressData.LANGUAGES:
		game.set_language(locale)
		for _frame in range(3):
			await process_frame
		var card := menu.get_node("Center/Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Rating fits: " + locale)
	view.free()


func _places(rows: Array[Dictionary]) -> Array:
	return rows.map(func(row: Dictionary) -> int: return row.place)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

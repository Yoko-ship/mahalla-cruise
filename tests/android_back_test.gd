extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.set_language("en")
	var hud := game.hud
	for button: Button in [hud.menu.garage_button, hud.menu.tasks_button, hud.menu.gift_button]:
		button.pressed.emit()
		_check(not hud.menu.visible, "A screen opens over the start card")
		_back(game)
		_check(hud.menu.visible and not hud.menu.is_pause, "Back returns to the start card")
	hud.menu.garage_button.pressed.emit()
	hud.garage_menu.market_pressed.emit()
	_back(game)
	_check(hud.garage_menu.visible and not hud.market_menu.visible, "Back leaves the market")
	_back(game)
	_check(hud.menu.visible, "Then the garage")
	_back(game)
	_check(hud.menu.visible and game.state == CruiseGame.RunState.START, "Back on start waits")
	game.start_run()
	game.world.player.set_physics_process(false)
	_back(game)
	_check(game.state == CruiseGame.RunState.PAUSED and hud.menu.is_pause, "Back pauses a drive")
	_back(game)
	_check(game.state == CruiseGame.RunState.PAUSED, "A second Back never resumes by itself")
	game.resume_run()
	game.progress.wallet = 1000
	game.distance_metres = game.revival.min_metres + 1.0
	game.world.traffic.contacted.emit()
	_check(hud.second_chance.visible, "A second chance is offered")
	_back(game)
	_check(game.is_game_over and hud.game_over_panel.visible, "Back declines it")
	game.free()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: Android Back closes screens, pauses drives, and declines (%d checks)" % checks)
	quit(1 if failures else 0)


## Android sends Back to every node, as the engine does on a phone.
func _back(game: CruiseGame) -> void:
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

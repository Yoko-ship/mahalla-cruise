extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_menu_and_pause()
	_test_lifecycle()
	await _test_touch_start()
	_test_hint_persistence()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: start, pause, focus lifecycle, touch, and first-run persistence (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _new_game(path: String = "") -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = path
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _test_menu_and_pause() -> void:
	var game := _new_game()
	_check(game.state == CruiseGame.RunState.START, "Launch opens the start state")
	_check(game.hud.menu.visible and game.hud.menu.car.visible, "Start screen shows the Damas")
	_check(not game.world.player.visible, "Start hero does not duplicate the road car")
	_check(game.hud.menu.detail.text == "Best: 0", "Start screen shows the local record")
	game.advance(100.0)
	Input.action_press("ui_right")
	game.world.player.advance(1.0)
	Input.action_release("ui_right")
	_check(
		game.distance_metres == 0.0 and game.world.player.position.x == 216.0,
		"Menu freezes gameplay"
	)
	game.resume_run()
	_check(game.state == CruiseGame.RunState.START, "Resume cannot bypass the start action")
	await _click(game.hud.menu.primary_button)
	game.world.player.set_physics_process(false)
	_check(game.state == CruiseGame.RunState.PLAYING, "Clicking Play starts the run")
	_check(game.world.player.visible, "Play reveals the drivable car")
	_check(
		not game.hud.menu.visible and game.hud.drive.pause_button.visible,
		"Play switches HUD controls"
	)
	_check(game.hud.drive.controls_label.visible, "First play displays the driving instructions")
	var traffic_settings := game.traffic_settings.duplicate() as TrafficSettings
	traffic_settings.first_spawn_distance = 1.0
	game.world.traffic.configure(game.road_settings, traffic_settings)
	game.advance(0.5)
	game.advance(0.5)
	var traffic_position: Vector2 = game.world.traffic.vehicles.front().position
	var difficulty := game.world.traffic.difficulty_progress
	var note: MoneyPickup = game.world.pickups.items.front()
	var distance := game.distance_metres
	var offset := game.world.scenery.scroll_offset
	var position := note.position
	var phase := note.visual.phase
	game.pickup_feedback.play_pickup(false)
	await _click(game.hud.drive.pause_button)
	_check(game.state == CruiseGame.RunState.PAUSED, "Pause button freezes the run")
	_check(game.hud.menu.primary_button.text == "Resume", "Pause offers a clear Resume action")
	_check(not game.pickup_feedback.som_sound.playing, "Pause stops pickup audio")
	_check(not game.hud.drive.controls_label.visible, "Paused menu hides the hint")
	game.advance(100.0)
	game.world.player.advance(100.0)
	_check(
		game.distance_metres == distance and game.world.scenery.scroll_offset == offset,
		"World is frozen"
	)
	_check(
		note.position == position and note.visual.phase == phase, "Paused money freezes completely"
	)
	_check(
		game.world.traffic.vehicles.front().position == traffic_position,
		"Traffic cannot move during pause"
	)
	_check(
		game.world.traffic.difficulty_progress == difficulty, "Paused time cannot raise difficulty"
	)
	game.world.pickups.collected.emit(100, game.pickup_settings.dollar_note)
	game.world.traffic.contacted.emit()
	_check(game.score == 0 and not game.is_game_over, "Paused signals cannot score or crash")
	game.start_run()
	game.restart_run()
	_check(game.state == CruiseGame.RunState.PAUSED, "Other actions cannot bypass pause")
	await _click(game.hud.menu.primary_button)
	game.world.player.set_physics_process(false)
	_check(game.state == CruiseGame.RunState.PLAYING, "Resume continues the same run")
	_check(game.hud.drive.controls_label.visible, "Resume restores the remaining hint")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 0)
	root.push_input(motion, true)
	game.world.player.advance(0.1)
	_check(
		game.world.player.position.x == 216.0, "Resume click cannot leave a steering gesture active"
	)
	game.advance(0.1)
	_check(
		game.distance_metres > distance and note.position.y > position.y, "World continues smoothly"
	)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	_check(game.state == CruiseGame.RunState.PAUSED, "Escape pauses through real input dispatch")
	key.pressed = false
	root.push_input(key, true)
	game.free()


func _test_lifecycle() -> void:
	var game := _new_game()
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.start_run()
	_check(game.state == CruiseGame.RunState.START, "An unfocused app cannot start")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.start_run()
	game.world.player.set_physics_process(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.state == CruiseGame.RunState.PAUSED, "OS suspension pauses the drive")
	game.resume_run()
	_check(game.state == CruiseGame.RunState.PAUSED, "Background resume is rejected")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(
		game.state == CruiseGame.RunState.PAUSED, "Returning to the app requires explicit Resume"
	)
	game.resume_run()
	game.world.player.set_physics_process(false)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(80, 0)
	root.push_input(drag, true)
	game.world.player.advance(0.1)
	_check(game.world.player.position.x == 216.0, "Old touch gestures cannot move the resumed car")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.state == CruiseGame.RunState.PAUSED, "Window focus loss also pauses")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.resume_run()
	game.world.traffic.contacted.emit()
	_check(game.is_game_over, "Crash still ends a resumed run")
	game.pause_run()
	game.resume_run()
	_check(game.is_game_over and not game.hud.menu.visible, "Game over cannot turn into pause")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(game.is_game_over, "Backgrounding a finished run preserves its results")
	game.restart_run()
	_check(game.state == CruiseGame.RunState.PLAYING, "Drive again enters a fresh playable state")
	_check(not game.hud.drive.controls_label.visible, "Restart does not repeat the first-run hint")
	game.free()


func _test_touch_start() -> void:
	var game := _new_game()
	await process_frame
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = (
		root.get_final_transform() * game.hud.menu.primary_button.get_global_rect().get_center()
	)
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	_check(game.state == CruiseGame.RunState.PLAYING, "Touch activates Play through UI emulation")
	game.free()


func _test_hint_persistence() -> void:
	var path := "user://hint_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game := _new_game(path)
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(game.progress.driving_hint_seen, "First play records onboarding completion")
	game.advance(3.0)
	game.pause_run()
	game.advance(30.0)
	game.resume_run()
	game.world.player.set_physics_process(false)
	game.advance(2.9)
	_check(
		game.hud.drive.controls_label.visible, "Paused time does not consume the six-second hint"
	)
	game.advance(0.2)
	_check(not game.hud.drive.controls_label.visible, "Hint expires after active driving time")
	game.free()
	game = _new_game(path)
	game.start_run()
	_check(
		not game.hud.drive.controls_label.visible, "Reopening does not repeat completed onboarding"
	)
	game.free()
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


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


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

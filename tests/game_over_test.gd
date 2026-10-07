extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_crash_and_mouse_restart()
	await _test_touch_restart()
	if failures == 0:
		print("PASS: game over, frozen run, and mouse/touch restart (%d checks)" % checks)
	quit(1 if failures else 0)


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	return game


func _crash(game: CruiseGame) -> void:
	game.advance(game.traffic_settings.first_spawn_distance / game.road_settings.scroll_speed)
	var vehicle: TrafficCar = game.traffic.vehicles.front()
	game.player.position.x = vehicle.position.x
	game.player.configure_bounds(game.road_settings.left_edge, game.road_settings.right_edge)
	var seconds_to_contact := game.player.position.y - vehicle.position.y
	seconds_to_contact /= game.road_settings.scroll_speed * game.traffic_settings.relative_speed
	game.advance(seconds_to_contact)


func _test_crash_and_mouse_restart() -> void:
	var game := _new_game()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	_crash(game)
	_check(game.is_game_over, "The first collision ends the run")
	_check(game.hud.game_over_panel.visible, "Collision shows the game-over overlay")
	_check(not game.player.is_physics_processing(), "Driving physics stops after a crash")
	_check(not paused, "The scene tree stays active so restart UI can respond")
	_check(
		game.hud.game_over_panel.result_label.text == "%d m travelled" % int(game.distance_metres),
		"The overlay displays the final distance"
	)
	var distance_before := game.distance_metres
	var road_before := game.road.scroll_offset
	var scenery_before := game.scenery.scroll_offset
	var traffic_before: Vector2 = game.traffic.vehicles.front().position
	var player_before := game.player.position
	var target_before := game.player.target_x
	var count_before := game.traffic.vehicles.size()
	game.advance(20.0)
	Input.action_press("ui_right")
	game.player.advance(1.0)
	Input.action_release("ui_right")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 0)
	root.push_input(motion, true)
	game.player.advance(1.0)
	_check(is_equal_approx(game.distance_metres, distance_before), "Final distance stays frozen")
	_check(is_equal_approx(game.road.scroll_offset, road_before), "Road stays frozen")
	_check(is_equal_approx(game.scenery.scroll_offset, scenery_before), "Scenery stays frozen")
	_check(game.traffic.vehicles.front().position == traffic_before, "Traffic stays frozen")
	_check(game.traffic.vehicles.size() == count_before, "No traffic spawns after game over")
	_check(game.player.position == player_before, "Keyboard and mouse cannot move a crashed car")
	_check(
		is_equal_approx(game.player.target_x, target_before),
		"Input cannot queue post-crash steering"
	)

	await process_frame
	await process_frame
	var button_center := game.hud.game_over_panel.restart_button.get_global_rect().get_center()
	press.position = button_center
	press.pressed = true
	root.push_input(press, true)
	press.pressed = false
	root.push_input(press, true)
	_check(not game.is_game_over, "Clicking Drive again starts a new run")
	_check(not game.hud.game_over_panel.visible, "Restart hides the game-over overlay")
	_check(is_zero_approx(game.distance_metres), "Restart resets distance")
	_check(game.traffic.vehicles.is_empty(), "Restart removes old traffic")
	_check(_car_children(game.traffic) == 0, "Old vehicles are detached immediately")
	_check(game.player.position == Vector2(216, 604), "Restart restores the starting position")
	_check(is_zero_approx(game.player.rotation), "Restart clears steering lean")
	_check(is_zero_approx(game.road.scroll_offset), "Restart resets the road")
	_check(is_zero_approx(game.scenery.scroll_offset), "Restart resets scenery")
	game.player.set_physics_process(false)
	root.push_input(motion, true)
	game.player.advance(0.1)
	_check(
		is_equal_approx(game.player.position.x, 216.0),
		"Old mouse gesture cannot resume after restart"
	)
	game.advance(0.1)
	_check(game.distance_metres > 0.0, "The new run advances normally")
	_check(game.traffic.vehicles.is_empty(), "Restart restores the initial clear-road delay")
	Input.action_press("ui_left")
	game.player.advance(0.1)
	Input.action_release("ui_left")
	_check(game.player.position.x < 216.0, "Steering works again in the new run")
	_crash(game)
	_check(game.is_game_over, "Collision still ends the second run")
	game.free()


func _test_touch_restart() -> void:
	var game := _new_game()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	_crash(game)
	await process_frame
	await process_frame
	# Input.parse_input_event exercises Godot's touch-to-mouse bridge used by Buttons.
	var center := game.hud.game_over_panel.restart_button.get_global_rect().get_center()
	touch.position = root.get_final_transform() * center
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	_check(not game.is_game_over, "Touching Drive again restarts through the real UI input path")
	game.player.set_physics_process(false)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(80, 0)
	root.push_input(drag, true)
	game.player.advance(0.1)
	_check(
		is_equal_approx(game.player.position.x, 216.0),
		"Old touch gesture cannot resume after restart"
	)
	game.free()


func _car_children(traffic: Node) -> int:
	# The traffic node also owns its sheep crossing; count only vehicles.
	return (
		traffic.get_children().filter(func(child: Node) -> bool: return child is TrafficCar).size()
	)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate() as CruiseGame
	(scene.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(scene)
	scene.start_run()
	var car := scene.get_node("PlayerCar") as PlayerCar
	scene.set_process(false)
	car.set_physics_process(false)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(10, 400)
	root.push_input(press, true)
	car.advance(0.1)
	_check(
		is_equal_approx(car.position.x, 216.0), "Pressing away from the car must not teleport it"
	)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 0)
	root.push_input(motion, true)
	car.advance(0.1)
	_check(is_equal_approx(car.position.x, 256.0), "Mouse drag moves the car")
	press.pressed = false
	root.push_input(press, true)
	root.push_input(motion, true)
	car.advance(0.1)
	_check(is_equal_approx(car.position.x, 256.0), "Mouse movement after release does not steer")

	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.relative = Vector2(-1000, 0)
	root.push_input(drag, true)
	car.advance(1.0)
	_check(is_equal_approx(car.position.x, 256.0), "A second finger must not take over steering")
	drag.index = 0
	root.push_input(drag, true)
	car.advance(1.0)
	_check(
		is_equal_approx(car.position.x, car.left_limit),
		"Large touch drag stops at the left road edge"
	)
	drag.relative = Vector2(2000, 0)
	root.push_input(drag, true)
	car.advance(1.0)
	_check(
		is_equal_approx(car.position.x, car.right_limit),
		"Large touch drag stops at the right road edge"
	)
	touch.pressed = false
	root.push_input(touch, true)
	drag.relative = Vector2(-1000, 0)
	root.push_input(drag, true)
	car.advance(1.0)
	_check(is_equal_approx(car.position.x, car.right_limit), "Released touch no longer steers")

	scene.advance(3600.0)
	_check(
		scene.road.scroll_offset >= 0.0 and scene.road.scroll_offset < 100.0,
		"Road scrolling wraps over long sessions"
	)
	_check(
		(
			scene.scenery.scroll_offset >= 0.0
			and scene.scenery.scroll_offset < SceneryView.REPEAT_DISTANCE
		),
		"Scenery scrolling wraps over long sessions"
	)
	_check(scene.distance_metres > 0.0, "Distance advances while driving")
	_test_keyboard_and_focus(car)
	_test_emulated_mouse_is_ignored(car)
	scene.free()
	_test_resource_configuration()
	_test_scenery_cycle()
	if failures == 0:
		print("PASS: driving, resource configuration, and HUD integration (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_keyboard_and_focus(car: PlayerCar) -> void:
	car.position.x = 216.0
	car.configure_bounds(90.0, 342.0)
	Input.action_press("ui_left")
	car.advance(0.1)
	Input.action_release("ui_left")
	_check(is_equal_approx(car.position.x, 152.0), "Arrow key steers at the configured speed")
	_check(
		absf(car.rotation) <= car.settings.max_lean,
		"Steering stays within the small configured visual lean"
	)
	car.advance(0.1)
	_check(
		is_equal_approx(car.position.x, 152.0), "Releasing the arrow key stops keyboard steering"
	)
	car.advance(1.0)
	_check(
		absf(car.rotation) < 0.0001, "After steering stops the vehicle returns to straight ahead"
	)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	car.steering.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(60, 0)
	root.push_input(motion, true)
	car.advance(0.1)
	_check(is_equal_approx(car.position.x, 152.0), "Losing focus cancels a mouse drag")


func _test_emulated_mouse_is_ignored(car: PlayerCar) -> void:
	car.position.x = 216.0
	car.configure_bounds(90.0, 342.0)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(20, 0)
	root.push_input(drag, true)
	car.advance(0.1)
	_check(is_equal_approx(car.position.x, 236.0), "A real touch drag steers once")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse, true)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.relative = Vector2(20, 0)
	root.push_input(motion, true)
	car.advance(0.1)
	_check(
		is_equal_approx(car.position.x, 236.0),
		"Emulated mouse motion does not double touch steering"
	)
	touch.pressed = false
	root.push_input(touch, true)
	mouse.pressed = false
	root.push_input(mouse, true)


func _test_resource_configuration() -> void:
	var scene := MAIN_SCENE.instantiate() as CruiseGame
	var car := scene.get_node("PlayerCar") as PlayerCar
	var original_settings := car.settings
	car.settings = original_settings.duplicate() as CarSettings
	car.settings.steering_speed = 100.0
	car.settings.drag_sensitivity = 0.5
	scene.road_settings = scene.road_settings.duplicate() as RoadSettings
	scene.road_settings.left_edge = 100.0
	scene.road_settings.right_edge = 332.0
	scene.road_settings.scroll_speed = 100.0
	(scene.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	car.set_physics_process(false)
	_check(
		is_equal_approx(car.left_limit, 126.0), "Road resource determines the player's left limit"
	)
	_check(
		is_equal_approx(car.right_limit, 306.0), "Road resource determines the player's right limit"
	)
	_check(
		is_equal_approx(original_settings.steering_speed, 640.0),
		"Car variants do not mutate shared defaults"
	)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 0)
	root.push_input(motion, true)
	car.advance(0.1)
	_check(is_equal_approx(car.position.x, 226.0), "Car resource controls movement speed")
	car.advance(1.0)
	_check(is_equal_approx(car.position.x, 236.0), "Car resource controls drag sensitivity")
	press.pressed = false
	root.push_input(press, true)

	scene.advance(2.5)
	_check(is_equal_approx(scene.distance_metres, 12.5), "Route speed controls distance")
	_check(
		is_equal_approx(scene.road.scroll_offset, 50.0), "Road receives the shared travel distance"
	)
	_check(
		is_equal_approx(scene.scenery.scroll_offset, 250.0),
		"Scenery receives the shared travel distance"
	)
	_check(scene.hud.distance_label.text == "12 m", "Compact HUD displays game distance")
	scene.free()


func _test_scenery_cycle() -> void:
	var scenery := SceneryView.new()
	var settings := RoadSettings.new()
	root.add_child(scenery)
	scenery.configure(settings)
	scenery.advance(SceneryView.REPEAT_DISTANCE - 0.5)
	scenery.advance(1.0)
	_check(is_equal_approx(scenery.scroll_offset, 0.5), "Scenery wraps across frame boundaries")
	scenery.advance(SceneryView.REPEAT_DISTANCE * 1000.0 + 25.0)
	_check(is_equal_approx(scenery.scroll_offset, 25.5), "Large travel preserves scenery phase")
	scenery.configure(settings)
	_check(is_zero_approx(scenery.scroll_offset), "Restart returns the scenery to its first block")
	scenery.advance(240.0)
	_check(is_equal_approx(scenery.scroll_offset, 240.0), "All three blocks play before repeating")
	scenery.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

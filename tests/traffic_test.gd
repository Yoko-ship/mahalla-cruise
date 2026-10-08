extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_spawning_and_cleanup()
	_test_swept_contact()
	_test_clear_pass()
	# A clear pass can collect money; let its short audio tail drain before shutdown.
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: traffic spacing, cleanup, and crash detection (%d checks)" % checks)
	quit(1 if failures else 0)


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _spawn_first(game: CruiseGame) -> TrafficCar:
	game.advance(game.traffic_settings.first_spawn_distance / game.road_settings.scroll_speed)
	return game.world.traffic.vehicles.front()


func _test_spawning_and_cleanup() -> void:
	var game := _new_game()
	_check(game.world.traffic.vehicles.is_empty(), "The player starts with a clear road")
	var first := _spawn_first(game)
	_check(first.position.y < 0, "Traffic enters from beyond the visible road")
	var clear_player := Rect2(-1000, -1000, 1, 1)
	var spaced: bool = true
	var within_road: bool = true
	var alternating: bool = true
	var last_id: int = first.get_instance_id()
	var last_lane_x: float = first.position.x
	var spawns: int = 1
	var peak_count: int = 0
	for frame in range(2400):
		game.world.traffic.advance(game.road_settings.scroll_speed / 60.0, clear_player)
		var cars := game.world.traffic.vehicles
		peak_count = maxi(peak_count, cars.size())
		for index in range(cars.size()):
			var bounds := cars[index].collision_bounds()
			within_road = within_road and bounds.position.x >= game.road_settings.left_edge
			within_road = within_road and bounds.end.x <= game.road_settings.right_edge
			if index > 0:
				var gap := absf(cars[index].position.y - cars[index - 1].position.y)
				spaced = spaced and gap >= game.traffic_settings.minimum_gap
		if not cars.is_empty() and cars.back().get_instance_id() != last_id:
			var middle := (game.road_settings.left_edge + game.road_settings.right_edge) * 0.5
			alternating = (
				alternating and (cars.back().position.x < middle) != (last_lane_x < middle)
			)
			last_lane_x = cars.back().position.x
			last_id = cars.back().get_instance_id()
			spawns += 1
		if frame % 120 == 0:
			await process_frame
	await process_frame
	_check(spawns > 5, "Traffic continues spawning through an extended drive")
	_check(spaced, "Successive cars preserve an open gap between them")
	_check(alternating, "Successive cars alternate lanes")
	_check(within_road, "Traffic stays inside the configured road edges")
	_check(peak_count <= game.traffic_settings.max_vehicles, "Active traffic stays bounded")
	_check(
		_car_children(game.world.traffic) == game.world.traffic.vehicles.size(),
		"Passed traffic nodes are freed, not just removed from the active list"
	)
	game.free()


func _test_swept_contact() -> void:
	var game := _new_game()
	var vehicle := _spawn_first(game)
	game.world.player.position.x = vehicle.position.x
	game.advance(10.0)
	_check(game.is_game_over, "A long frame cannot skip a car crossing the player")
	game.free()


func _test_clear_pass() -> void:
	var game := _new_game()
	var vehicle := _spawn_first(game)
	var side := 1.0 if vehicle.position.x < 216.0 else -1.0
	game.world.player.position.x = vehicle.position.x + side * 45.0
	game.advance(10.0)
	_check(not game.is_game_over, "Passing beside traffic does not cause a false collision")
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

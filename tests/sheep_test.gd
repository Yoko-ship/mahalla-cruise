extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const SHEEP: SheepSettings = preload("res://src/traffic/default_sheep.tres")
const FAR_AWAY := Rect2(-5000, -5000, 1, 1)
const STEP_PIXELS: float = 220.0 / 30.0

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_first_crossing()
	_test_always_passable()
	_test_cars_and_sheep_never_overlap()
	_test_contact_and_restart()
	_test_money_and_sheep_stay_apart()
	_check(SHEEP.first_crossing_metres == 250.0 and SHEEP.flock_size_max == 3, "Defaults unchanged")
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: sheep crossings, passable flocks, car clearance, and contact (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_first_crossing() -> void:
	var game := _new_game(false)
	var traffic := game.world.traffic
	var crossing := traffic.sheep_crossing
	traffic.set_distance(249.0)
	traffic.advance(STEP_PIXELS, FAR_AWAY)
	_check(crossing.flock.is_empty(), "No sheep before the first crossing distance")
	traffic.set_distance(250.0)
	traffic.advance(STEP_PIXELS, FAR_AWAY)
	_check(crossing.flock.size() >= 2 and crossing.flock.size() <= 3, "A flock of two or three")
	var road := game.road_settings
	var direction := crossing.flock[0].direction
	for sheep in crossing.flock:
		var bounds := sheep.collision_bounds()
		_check(sheep.direction == direction, "The flock walks together")
		_check(
			bounds.end.x < road.left_edge or bounds.position.x > road.right_edge,
			"Sheep start on a sidewalk, off the road"
		)
		_check(sheep.position.y < 0.0, "Sheep appear above the visible road")
	_check(traffic.blocking_bounds().size() == crossing.flock.size(), "Money avoids the flock")
	var leader := crossing.flock[0]
	var start_x := leader.position.x
	traffic.advance(40.0, FAR_AWAY)
	_check(
		is_equal_approx(leader.position.x - start_x, 40.0 * SHEEP.walk_per_travel * direction),
		"Sheep walk sideways in step with road travel"
	)
	for _step in range(200):
		traffic.advance(STEP_PIXELS, FAR_AWAY)
	for sheep in crossing.flock:
		var bounds := sheep.collision_bounds()
		_check(
			bounds.end.x < road.left_edge or bounds.position.x > road.right_edge,
			"Sheep finish on the far sidewalk"
		)
	_check(crossing.next_crossing_metres >= 850.0, "The next crossing is 600–1000 m later")
	game.free()


func _test_always_passable() -> void:
	var game := _new_game(false)
	var traffic := game.world.traffic
	var crossing := traffic.sheep_crossing
	var row := game.world.player.collision_bounds()
	var half := row.size.x * 0.5
	var left_lane := Rect2(
		game.world.player.left_limit - half, row.position.y, row.size.x, row.size.y
	)
	var right_lane := Rect2(
		game.world.player.right_limit - half, row.position.y, row.size.x, row.size.y
	)
	var metres := 0.0
	var crossings := 0
	var blocked_frames := 0
	while crossings < 120:
		traffic.set_distance(metres)
		var was_empty := crossing.flock.is_empty()
		traffic.advance(STEP_PIXELS, FAR_AWAY)
		if was_empty and not crossing.flock.is_empty():
			crossings += 1
		var left_open := true
		var right_open := true
		for bounds in crossing.blocking_bounds():
			left_open = left_open and not bounds.intersects(left_lane)
			right_open = right_open and not bounds.intersects(right_lane)
		if not left_open and not right_open:
			blocked_frames += 1
		metres += STEP_PIXELS / game.road_settings.pixels_per_metre
	_check(blocked_frames == 0, "Every flock leaves one road edge open to the player")
	game.free()


func _test_cars_and_sheep_never_overlap() -> void:
	var game := _new_game(true)
	var traffic := game.world.traffic
	var crossing := traffic.sheep_crossing
	var metres := 0.0
	var overlaps := 0
	var crossings := 0
	var cars_after_crossing := false
	while metres < 6000.0:
		traffic.set_distance(metres)
		var was_empty := crossing.flock.is_empty()
		traffic.advance(STEP_PIXELS, FAR_AWAY)
		if was_empty and not crossing.flock.is_empty():
			crossings += 1
		for sheep in crossing.flock:
			for vehicle in traffic.vehicles:
				if sheep.collision_bounds().intersects(vehicle.collision_bounds()):
					overlaps += 1
			if crossings > 0 and traffic.vehicles.size() > 0 and sheep.position.y > 700.0:
				cars_after_crossing = true
		metres += STEP_PIXELS / game.road_settings.pixels_per_metre
	_check(overlaps == 0, "Sheep never walk into traffic")
	_check(crossings >= 6, "Busy traffic still makes room for crossings")
	_check(cars_after_crossing, "Traffic keeps flowing behind a flock")
	game.free()


func _test_contact_and_restart() -> void:
	var game := _new_game(false)
	game.start_run()
	game.set_process(false)
	game.world.player.set_physics_process(false)
	game.world.traffic.set_distance(300.0)
	game.world.traffic.advance(STEP_PIXELS, FAR_AWAY)
	var sheep: Sheep = game.world.traffic.sheep_crossing.flock[0]
	sheep.position = game.world.player.position - Vector2(0, 40)
	game.advance(0.2)
	_check(game.is_game_over and sheep.has_contacted, "Hitting a sheep ends the run")
	_check(game.world.traffic.last_contact_kind == "sheep", "The crash is reported as sheep")
	var message := game.hud.game_over_panel.message_label.text
	_check(message == "The sheep had right of way!", "Results explain the sheep crash")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(game.world.traffic.sheep_crossing.flock.is_empty(), "Restart clears the flock")
	_check(
		game.world.traffic.sheep_crossing.next_crossing_metres == 250.0, "Restart resets crossings"
	)
	game.world.traffic.contacted.emit()
	_check(
		game.hud.game_over_panel.message_label.text == "You hit another car.",
		"Car crashes keep their message"
	)
	game.free()


func _test_money_and_sheep_stay_apart() -> void:
	var game := _new_game(false)
	var traffic := game.world.traffic
	var pickups := game.world.pickups
	var metres := 0.0
	var touching := 0
	var crossings := 0
	var notes := 0
	while metres < 8000.0:
		traffic.set_distance(metres)
		var was_empty := traffic.sheep_crossing.flock.is_empty()
		var before := pickups.items.size()
		pickups.advance(
			STEP_PIXELS, FAR_AWAY, traffic.blocking_bounds(), game.traffic_settings.relative_speed
		)
		notes += maxi(0, pickups.items.size() - before)
		traffic.advance(STEP_PIXELS, FAR_AWAY, pickups.item_bounds())
		if was_empty and not traffic.sheep_crossing.flock.is_empty():
			crossings += 1
		for sheep in traffic.sheep_crossing.blocking_bounds():
			for note in pickups.item_bounds():
				if sheep.intersects(note):
					touching += 1
		metres += STEP_PIXELS / game.road_settings.pixels_per_metre
	_check(touching == 0, "Sheep never walk onto money")
	_check(crossings >= 8 and notes >= 100, "Money and crossings both keep appearing")
	game.free()


func _new_game(with_cars: bool) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	if not with_cars:
		game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
		game.traffic_settings.first_spawn_distance = 1.0e9
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	return game


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

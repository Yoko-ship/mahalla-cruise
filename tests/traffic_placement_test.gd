extends SceneTree

const SETTINGS: TrafficSettings = preload("res://src/traffic/default_traffic.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")
const PLAYER: CarSettings = preload("res://src/driving/default_car.tres")
const TRAFFIC: PackedScene = preload("res://src/traffic/traffic.tscn")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_lane_geometry()
	_test_no_permanently_safe_position()
	await _test_live_traffic()
	await _test_steerable_run(60)
	await _test_steerable_run(15)
	# Music plays during drives; let the mixer release it before the engine exits.
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: traffic variation, visible paths, and safe passing room (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_lane_geometry() -> void:
	var middle := (ROAD.left_edge + ROAD.right_edge) * 0.5
	for lane in [0, 1]:
		var outer := SETTINGS.lane_x(ROAD.left_edge, ROAD.right_edge, lane, 0.0)
		var inner := SETTINGS.lane_x(ROAD.left_edge, ROAD.right_edge, lane, 1.0)
		_check(absf(inner - outer) == 12.0, "Variation stays within its twelve-pixel allowance")
		_check(
			absf(inner - middle) < absf(outer - middle), "Variation moves toward the road center"
		)
		var lane_edge := inner + SETTINGS.collision_half_size.x * (1.0 if lane == 0 else -1.0)
		_check(lane_edge < middle if lane == 0 else lane_edge > middle, "Car stays in its lane")
		var safe_x := ROAD.right_edge - PLAYER.road_margin if lane == 0 else ROAD.left_edge
		if lane == 1:
			safe_x += PLAYER.road_margin
		_check(
			absf(safe_x - inner) > SETTINGS.collision_half_size.x + PLAYER.collision_half_size.x,
			"A car at the innermost position leaves passing room on the opposite side"
		)
		_check(
			SETTINGS.lane_x(ROAD.left_edge, ROAD.right_edge, lane, -1.0) == outer,
			"A roll below zero clamps to the outer position"
		)
		_check(
			SETTINGS.lane_x(ROAD.left_edge, ROAD.right_edge, lane, 2.0) == inner,
			"A roll above one clamps to the inner position"
		)
	var fixed := SETTINGS.duplicate() as TrafficSettings
	fixed.lane_inset_pixels = 0.0
	_check(fixed.lane_x(124, 308, 0, 1.0) == 170.0, "Zero inset restores fixed lane centers")
	_check(
		SETTINGS.lane_inset_pixels == 12.0, "Sampling and variants leave shared tuning unchanged"
	)


func _test_no_permanently_safe_position() -> void:
	var total_width := SETTINGS.collision_half_size.x + PLAYER.collision_half_size.x
	var covered := true
	for x in range(
		int(ROAD.left_edge + PLAYER.road_margin), int(ROAD.right_edge - PLAYER.road_margin) + 1
	):
		var can_be_reached := false
		for lane in [0, 1]:
			for roll in [0.0, 1.0]:
				var traffic_x := SETTINGS.lane_x(ROAD.left_edge, ROAD.right_edge, lane, roll)
				can_be_reached = can_be_reached or absf(x - traffic_x) < total_width
		covered = covered and can_be_reached
	_check(covered, "Every legal stationary position can meet visible traffic")
	var approach_seconds := (
		(604.0 - SETTINGS.spawn_y - 72.0) / (ROAD.scroll_speed * SETTINGS.relative_speed)
	)
	_check(approach_seconds > 4.0, "Even an inward car gives over four seconds of approach time")


func _test_live_traffic() -> void:
	var traffic := TRAFFIC.instantiate() as TrafficController
	root.add_child(traffic)
	traffic.configure(ROAD, SETTINGS)
	traffic.set_distance(SETTINGS.difficulty_full_metres)
	var previous_lane: int = -1
	var previous_id: int = 0
	var spawns: int = 0
	var alternating := true
	var in_lane := true
	var positions: Dictionary[int, float] = {}
	var straight := true
	for frame in range(3000):
		traffic.advance(4.0, Rect2(-1000, 604, 1, 1))
		for vehicle in traffic.vehicles:
			var id := vehicle.get_instance_id()
			if positions.has(id):
				straight = straight and vehicle.position.x == positions[id]
			else:
				positions[id] = vehicle.position.x
		if not traffic.vehicles.is_empty():
			var newest: TrafficCar = traffic.vehicles.back()
			if newest.get_instance_id() != previous_id:
				var lane := 0 if newest.position.x < 216.0 else 1
				alternating = alternating and lane != previous_lane
				var outer := SETTINGS.lane_x(124, 308, lane, 0.0)
				var inner := SETTINGS.lane_x(124, 308, lane, 1.0)
				in_lane = in_lane and newest.position.x >= minf(outer, inner)
				in_lane = in_lane and newest.position.x <= maxf(outer, inner)
				previous_lane = lane
				previous_id = newest.get_instance_id()
				spawns += 1
		if frame % 120 == 0:
			await process_frame
	_check(spawns > 15, "The check exercises many actual spawns at maximum difficulty")
	_check(alternating, "Traffic still alternates sides instead of blocking both lanes together")
	_check(in_lane, "Actual cars use the configured placement bounds")
	_check(straight, "Traffic never changes its horizontal path after becoming visible")
	traffic.free()


func _test_steerable_run(frames_per_second: int) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 912)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.pickup_feedback.set_sound_enabled(false)
	game.start_run()
	game.world.player.set_physics_process(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	view.push_input(touch, true)
	var delta := 1.0 / frames_per_second
	for frame in range(120 * frames_per_second):
		var nearest: TrafficCar = null
		for vehicle in game.world.traffic.vehicles:
			if vehicle.collision_bounds().position.y > game.world.player.collision_bounds().end.y:
				continue
			if nearest == null or vehicle.position.y > nearest.position.y:
				nearest = vehicle
		var target := 216.0
		if nearest != null:
			target = (
				game.world.player.right_limit
				if nearest.position.x < 216.0
				else game.world.player.left_limit
			)
		var flock := game.world.traffic.sheep_crossing.blocking_bounds()
		if not flock.is_empty() and (nearest == null or flock[0].position.y > nearest.position.y):
			# Sheep cross the whole road; drive past the side of the flock with more room.
			var span := flock[0]
			for sheep in flock:
				span = span.merge(sheep)
			var left_room := span.position.x - game.road_settings.left_edge
			var right_room := game.road_settings.right_edge - span.end.x
			target = (
				game.world.player.left_limit
				if left_room > right_room
				else game.world.player.right_limit
			)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.relative = Vector2(target - game.world.player.target_x, 0.0)
		view.push_input(drag, true)
		game.world.player.advance(delta)
		game.advance(delta)
		if game.is_game_over:
			break
		if frame % 120 == 0:
			await process_frame
	_check(
		not game.is_game_over,
		"Visible traffic and sheep can be avoided at %d FPS" % frames_per_second
	)
	_check(game.distance_metres >= 1319.0, "Steered run passes the full difficulty ramp")
	view.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

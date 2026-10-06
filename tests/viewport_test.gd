extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const SIZES: Array[Vector2i] = [Vector2i(432, 768), Vector2i(432, 960), Vector2i(576, 768)]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for size in SIZES:
		await _test_layout(size)
	await _test_resize()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: phone viewport layout, safe spawning, and resize lifecycle (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _new_view(size: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	return view


func _test_layout(size: Vector2i) -> void:
	var view := _new_view(size)
	var game := view.get_child(0) as CruiseGame
	var offset := (Vector2(size) - Vector2(432, 768)) * 0.5
	await process_frame
	await process_frame
	_check(game.position == offset, "Playfield centers in the available viewport")
	_check(game.player.position == Vector2(216, 604), "Layout preserves player coordinates")
	_check(game.player.global_position == Vector2(216, 604) + offset, "Car follows the playfield")
	_check(game.hud.pause_button.position == Vector2(18, 92) + offset, "Pause follows the road")
	_check(game.hud.menu.size == Vector2(size), "Menu shade covers the full viewport")
	var card := game.hud.menu.get_node("Center/Card") as Control
	_check(
		card.get_global_rect().get_center().distance_to(Vector2(size) * 0.5) <= 0.71,
		"Menu card centers independently of world coordinates"
	)
	_check(Rect2(Vector2.ZERO, size).encloses(card.get_global_rect()), "Menu fits the viewport")
	game.start_run()
	game.player.set_physics_process(false)
	_check(game.state == CruiseGame.RunState.PLAYING, "Layout does not prevent starting")
	game.hud.show_pickup(1, "1 000 soʻm")
	_check(game.hud.pickup_label.position.y == 510.0 + offset.y, "Feedback follows the car")
	_test_spawn_edges(game, offset.y)
	game.traffic.contacted.emit()
	_check(game.is_game_over, "Collision still ends a resized run")
	game.restart_run()
	game.player.set_physics_process(false)
	_check(game.player.position == Vector2(216, 604), "Restart restores the local car position")
	game.traffic.advance(game.traffic_settings.first_spawn_distance, Rect2(-1000, 0, 1, 1))
	_check(
		game.traffic.vehicles.front().position.y == game.traffic_settings.spawn_y - offset.y,
		"Restart preserves offscreen spawn placement"
	)
	view.free()


func _test_spawn_edges(game: CruiseGame, padding: float) -> void:
	var absent_player := Rect2(-1000, 604, 1, 1)
	game.traffic.advance(game.traffic_settings.first_spawn_distance, absent_player)
	var vehicle: TrafficCar = game.traffic.vehicles.front()
	_check(vehicle.collision_bounds().end.y < -padding, "Traffic begins beyond the visible top")
	game.pickups.advance(game.pickup_settings.first_spawn_distance, absent_player, [], 0.62)
	var item: MoneyPickup = game.pickups.items.front()
	_check(item.collection_bounds().end.y < -padding, "Money begins beyond the visible top")
	if padding > 0.0:
		vehicle.position.y = game.traffic_settings.despawn_y + 1.0
		item.position.y = game.pickup_settings.despawn_y + 1.0
		game.traffic.advance(0.0, absent_player)
		game.pickups.advance(0.0, absent_player, [], 0.62)
		_check(game.traffic.vehicles.has(vehicle), "Visible traffic stays on taller screens")
		_check(game.pickups.items.has(item), "Visible money stays on taller screens")
	vehicle.position.y = game.traffic_settings.despawn_y + padding + 1.0
	item.position.y = game.pickup_settings.despawn_y + padding + 1.0
	game.traffic.advance(0.0, absent_player)
	game.pickups.advance(0.0, absent_player, [], 0.62)
	_check(not game.traffic.vehicles.has(vehicle), "Traffic cleans up beyond the extended bottom")
	_check(not game.pickups.items.has(item), "Money cleans up beyond the extended bottom")
	if padding > 0.0:
		var obstacle: Array[Rect2] = [Rect2(-1000, -240, 3000, 80)]
		game.pickups.configure(game.road_settings, game.pickup_settings)
		game.pickups.advance(100.0, game.player.collision_bounds(), obstacle, 0.62)
		_check(game.pickups.items.is_empty(), "Extended spawn checks nearby offscreen traffic")
		game.pickups.advance(0.0, game.player.collision_bounds(), [], 0.62)
		_check(game.pickups.items.size() == 1, "Blocked pickup retries when its path becomes safe")
	_check(game.traffic_settings.spawn_y == -60.0, "Layout leaves traffic settings immutable")
	_check(game.pickup_settings.spawn_y == -32.0, "Layout leaves pickup settings immutable")


func _test_resize() -> void:
	var view := _new_view(Vector2i(432, 768))
	var game := view.get_child(0) as CruiseGame
	game.start_run()
	game.player.set_physics_process(false)
	game.advance(0.25)
	var distance := game.distance_metres
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	view.push_input(touch, true)
	view.size = Vector2i(432, 960)
	await process_frame
	_check(game.state == CruiseGame.RunState.PAUSED, "Resizing safely pauses a running game")
	game.advance(10.0)
	_check(game.distance_metres == distance, "Resize preserves the current distance")
	game.resume_run()
	game.player.set_physics_process(false)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(80, 0)
	view.push_input(drag, true)
	game.player.advance(0.1)
	_check(game.player.position.x == 216.0, "Resize cancels the previous steering gesture")
	for size in [Vector2i(576, 768), Vector2i(432, 960), Vector2i(432, 768)]:
		view.size = size
		await process_frame
	_check(game.position == Vector2.ZERO, "Returning to the original size clears the offset")
	_check(game.hud.pause_button.position == Vector2(18, 92), "Repeated resizing cannot drift UI")
	view.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const PICKUP_SCENE: PackedScene = preload("res://src/pickups/pickups.tscn")
const DEFAULTS: PickupSettings = preload("res://src/pickups/default_pickups.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_collection(false)
	_test_collection(true)
	_test_missed_money()
	_test_crash_and_reset()
	_test_safe_spawning()
	_test_cleanup_and_cap()
	# The mixer releases stopped sounds asynchronously after scene cleanup.
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: money scoring, safe spawning, cleanup, and restart (%d checks)" % checks)
	quit(1 if failures else 0)


func _new_game(dollars: bool = false) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.pickup_settings = game.pickup_settings.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0
	game.pickup_settings.spawn_distance = 1000.0
	game.pickup_settings.dollar_chance = 1.0 if dollars else 0.0
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_language("en")
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	return game


func _test_collection(dollars: bool) -> void:
	var game := _new_game(dollars)
	_check(game.score == 0 and game.pickups.items.is_empty(), "A new run starts without money")
	game.advance(1.0 / game.road_settings.scroll_speed)
	var item: MoneyPickup = game.pickups.items.front()
	_check(item.is_dollar == dollars, "Chance endpoints select the requested currency")
	_check(item.position.y < 0, "Money enters above the screen")
	var expected := game.pickup_settings.points_for(item.denomination)
	# One long frame passes the whole note through the player; a point test would miss it.
	game.advance(3.5)
	_check(game.score == expected, "Swept collection awards the correct currency value")
	_check(game.som_collected == (0 if dollars else 1), "Soʻm count matches the collected note")
	_check(
		game.dollars_collected == (1 if dollars else 0), "Dollar count matches the collected note"
	)
	_check(game.pickups.items.is_empty(), "Collected money is removed immediately")
	_check(game.pickups.get_child_count() == 0, "Collected nodes detach immediately")
	_check(game.hud.score_label.text == "%d pts" % expected, "HUD shows the awarded points")
	_check(game.hud.pickup_label.visible, "A collection shows feedback")
	game.advance(0.0)
	_check(game.score == expected, "A note cannot award points twice")
	_check(DEFAULTS.dollar_chance == 0.12, "Test variants and play leave shared settings unchanged")
	game.free()


func _test_missed_money() -> void:
	var game := _new_game()
	game.advance(1.0 / game.road_settings.scroll_speed)
	game.player.position.x = game.player.right_limit
	game.advance(4.0)
	_check(game.score == 0, "Driving beside money does not collect it")
	_check(game.pickups.items.is_empty(), "Missed money is removed below the screen")
	game.free()


func _test_crash_and_reset() -> void:
	var game := _new_game()
	game.advance(1.0 / game.road_settings.scroll_speed)
	game.advance(3.5)
	var before := game.score
	game.pickups.advance(1000.0, Rect2(-1000, 568, 40, 72), [], 0.62)
	var note: MoneyPickup = game.pickups.items.front()
	note.position = game.player.position - Vector2(0, 100)
	var traffic_variant := game.traffic_settings.duplicate() as TrafficSettings
	traffic_variant.first_spawn_distance = 1.0
	game.traffic.configure(game.road_settings, traffic_variant)
	game.traffic.advance(1.0, game.player.collision_bounds())
	var vehicle: TrafficCar = game.traffic.vehicles.front()
	vehicle.position = game.player.position - Vector2(0, 90)
	game.advance(0.5)
	_check(game.is_game_over, "Collision still ends a run containing money")
	_check(game.score == before, "Crash takes priority over a pickup in the same frame")
	_check(
		game.hud.game_over_panel.score_result.text == "%d points" % before,
		"Game over keeps the final score"
	)
	_check(
		game.hud.game_over_panel.money_result.text == "soʻm × 1    ·    $ × 0",
		"Game over shows the currency counts"
	)
	_check(not game.hud.pickup_label.visible, "Game over clears transient collection feedback")
	var frozen_position := note.position
	var frozen_phase := note.visual.phase
	game.advance(10.0)
	_check(note.position == frozen_position, "Money stops moving after a crash")
	_check(note.visual.phase == frozen_phase, "Collectible animation also freezes")
	_check(game.score == before, "Game-over frames cannot change the score")
	game.hud.game_over_panel.restart_button.pressed.emit()
	_check(not game.is_game_over, "The restart signal starts a fresh scored run")
	_check(
		game.score == 0 and game.som_collected == 0 and game.dollars_collected == 0,
		"Restart clears all run totals"
	)
	_check(
		game.pickups.items.is_empty() and game.pickups.get_child_count() == 0,
		"Restart clears every old note"
	)
	_check(game.hud.score_label.text == "0 pts", "Restart clears the displayed score")
	_check(not game.hud.pickup_label.visible, "Old pickup feedback cannot reappear on restart")
	game.player.set_physics_process(false)
	game.advance(0.0)
	_check(game.pickups.items.is_empty(), "Restart restores the initial spawn delay")
	game.free()


func _test_safe_spawning() -> void:
	var controller := PICKUP_SCENE.instantiate() as PickupController
	root.add_child(controller)
	var road := RoadSettings.new()
	var settings := DEFAULTS.duplicate() as PickupSettings
	var player := Rect2(196, 568, 40, 72)
	controller.configure(road, settings)
	var blocked: Array[Rect2] = [Rect2(124, 64, 184, 72)]
	controller.advance(settings.first_spawn_distance, player, blocked, 0.62)
	_check(controller.items.is_empty(), "No note spawns when traffic blocks every route")
	var centre_blocked: Array[Rect2] = [Rect2(196, 64, 40, 72)]
	controller.advance(1.0, player, centre_blocked, 0.62)
	_check(controller.items.size() == 1, "Spawning resumes when another route is clear")
	var item: MoneyPickup = controller.items.front()
	_check(item.position.x > 216.0, "Money avoids traffic along its future path")
	_check(
		(
			item.collection_bounds().position.x >= road.left_edge
			and item.collection_bounds().end.x <= road.right_edge
		),
		"Money fits inside the road"
	)
	controller.advance(0.0, player, [], 0.62)
	_check(controller.items.size() == 1, "A zero-travel frame cannot duplicate a spawn")
	controller.configure(road, settings)
	_check(
		controller.items.is_empty() and controller.get_child_count() == 0,
		"Reconfiguration clears notes immediately"
	)
	controller.free()


func _test_cleanup_and_cap() -> void:
	var controller := PICKUP_SCENE.instantiate() as PickupController
	root.add_child(controller)
	var settings := DEFAULTS.duplicate() as PickupSettings
	settings.spawn_distance = 80.0
	settings.max_pickups = 2
	controller.configure(RoadSettings.new(), settings)
	var bounded := true
	var detached := true
	var last_id: int = 0
	var spawns: int = 0
	for frame in range(2400):
		controller.advance(4.0, Rect2(-1000, 568, 40, 72), [], 0.62)
		bounded = bounded and controller.items.size() <= settings.max_pickups
		# Power-ups share this node; each kind of child must match its live list.
		detached = detached and _children(controller, MoneyPickup) == controller.items.size()
		detached = detached and _children(controller, PowerUp) == controller.power_ups.size()
		if not controller.items.is_empty() and controller.items.back().get_instance_id() != last_id:
			last_id = controller.items.back().get_instance_id()
			spawns += 1
	_check(bounded, "Active money stays within its configured cap")
	_check(detached, "Expired nodes never accumulate in the scene tree")
	_check(spawns > 10, "Spawning continues after missed notes are cleaned up")
	controller.free()


func _children(parent: Node, type: Variant) -> int:
	return (
		parent
		. get_children()
		. filter(func(child: Node) -> bool: return is_instance_of(child, type))
		. size()
	)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

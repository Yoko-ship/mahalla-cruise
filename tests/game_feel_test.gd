extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const TRAFFIC_SCENE: PackedScene = preload("res://src/traffic/traffic.tscn")
const TRAFFIC_DEFAULTS: TrafficSettings = preload("res://src/traffic/default_traffic.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_feedback()
	_test_collection_feedback_and_restart()
	_test_difficulty_curve()
	var early := _measure_traffic(0.0)
	var late := _measure_traffic(TRAFFIC_DEFAULTS.difficulty_full_metres)
	_check(late > early, "Late runs actually spawn more traffic over the same travel distance")
	await process_frame
	await process_frame
	# Let the audio mixer release stopped playbacks before engine shutdown.
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: pickup feedback, controls, and gradual difficulty (%d checks)" % checks)
	quit(1 if failures else 0)


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	return game


func _test_feedback() -> void:
	var game := _new_game()
	var feedback := game.pickup_feedback
	feedback.play_pickup(false)
	_check(feedback.som_sound.playing, "A soʻm pickup starts the short chime")
	_check(not feedback.dollar_sound.playing, "Soʻm does not play the dollar chime")
	_check(
		feedback.som_sound.stream != feedback.dollar_sound.stream,
		"The two currencies have different sounds"
	)
	feedback.play_pickup(true)
	_check(not feedback.dollar_sound.playing, "Rapid collection bursts do not stack extra feedback")
	feedback.stop()
	_check(not feedback.som_sound.playing, "Stopping feedback stops active playback")
	feedback.play_pickup(true)
	_check(feedback.dollar_sound.playing, "A dollar pickup starts its brighter chime")
	feedback.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not feedback.dollar_sound.playing, "Losing focus stops pickup sounds")
	feedback.play_pickup(false)
	_check(not feedback.som_sound.playing, "Background collections cannot make sounds")
	feedback.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.hud.sound_button.button_pressed = false
	_check(not feedback.sound_enabled, "HUD sound toggle routes through main to feedback")
	feedback.play_pickup(false)
	_check(not feedback.som_sound.playing, "Muted collections do not start audio")
	game.hud.haptics_button.button_pressed = false
	_check(not feedback.haptics_enabled, "Vibration has an independent runtime toggle")
	_check(
		feedback.settings.sound_enabled and feedback.settings.haptics_enabled,
		"Toggles never mutate shared defaults"
	)
	game.hud.sound_button.button_pressed = true
	feedback.stop()
	feedback.play_pickup(false)
	_check(feedback.som_sound.playing, "Sound can be enabled again")
	game.free()


func _test_collection_feedback_and_restart() -> void:
	var game := _new_game()
	# The first note is on the centre path; the event must reach audio through main.
	game.advance(game.pickup_settings.first_spawn_distance / game.road_settings.scroll_speed)
	game.advance(3.0)
	var feedback := game.pickup_feedback
	_check(game.score > 0, "A real pickup is collected during feedback integration testing")
	_check(
		feedback.som_sound.playing or feedback.dollar_sound.playing, "Real collection plays audio"
	)
	game.traffic.set_distance(game.traffic_settings.difficulty_full_metres)
	game.player.position.x = game.traffic.vehicles.front().position.x
	game.advance(5.0)
	_check(game.is_game_over, "Traffic still causes game over with the feedback module")
	_check(
		not feedback.som_sound.playing and not feedback.dollar_sound.playing,
		"Crash stops both chimes"
	)
	var frozen := game.traffic.difficulty_progress
	game.advance(1000.0)
	_check(game.traffic.difficulty_progress == frozen, "Difficulty stops advancing at game over")
	game.hud.sound_button.button_pressed = false
	game.hud.haptics_button.button_pressed = false
	game.restart_run()
	game.player.set_physics_process(false)
	_check(is_zero_approx(game.traffic.difficulty_progress), "Restart restores initial difficulty")
	_check(
		not feedback.sound_enabled and not feedback.haptics_enabled,
		"Restart retains the player's feedback preferences"
	)
	_check(
		not feedback.som_sound.playing and not feedback.dollar_sound.playing,
		"Restart has no leftover sounds"
	)
	_check(game.hud.sound_button.text == "Sound off", "HUD retains the selected mute state")
	game.free()


func _test_difficulty_curve() -> void:
	var game := _new_game()
	var settings := game.traffic_settings
	game.traffic.set_distance(0.0)
	_check(is_zero_approx(game.traffic.difficulty_progress), "A run starts at the easy baseline")
	game.traffic.set_distance(settings.difficulty_start_metres)
	_check(is_zero_approx(game.traffic.difficulty_progress), "The opening section stays gentle")
	game.traffic.set_distance(
		(settings.difficulty_start_metres + settings.difficulty_full_metres) / 2.0
	)
	_check(
		is_equal_approx(game.traffic.difficulty_progress, 0.5),
		"Difficulty increases smoothly midway through the ramp"
	)
	game.traffic.set_distance(settings.difficulty_full_metres)
	_check(
		is_equal_approx(game.traffic.difficulty_progress, 1.0),
		"Difficulty reaches its configured cap"
	)
	game.traffic.set_distance(1000000.0)
	_check(
		is_equal_approx(game.traffic.difficulty_progress, 1.0),
		"Very long runs never exceed the difficulty cap"
	)
	game.traffic.configure(game.road_settings, settings)
	game.advance(
		(
			(settings.difficulty_start_metres + 50.0)
			/ game.road_settings.scroll_speed
			* game.road_settings.pixels_per_metre
		)
	)
	_check(
		game.traffic.difficulty_progress > 0.0, "Main supplies actual run distance to difficulty"
	)
	_check(
		settings.spawn_distance_min == 550.0 and settings.spawn_distance_max == 720.0,
		"Progression does not modify shared spawn settings"
	)
	_check(
		settings.relative_speed == 0.62, "Traffic speed stays stable for pickup path predictions"
	)
	game.free()


func _measure_traffic(distance: float) -> int:
	var traffic := TRAFFIC_SCENE.instantiate() as TrafficController
	root.add_child(traffic)
	traffic.configure(RoadSettings.new(), TRAFFIC_DEFAULTS)
	traffic.set_distance(distance)
	var last_id: int = 0
	var spawns: int = 0
	var safe := true
	var bounded := true
	var alternating := true
	var previous_x: float = -1.0
	for frame in range(4000):
		traffic.advance(4.0, Rect2(-1000, -1000, 1, 1))
		var cars := traffic.vehicles
		bounded = bounded and cars.size() <= TRAFFIC_DEFAULTS.max_vehicles
		for index in range(1, cars.size()):
			safe = (
				safe
				and (
					absf(cars[index].position.y - cars[index - 1].position.y)
					>= TRAFFIC_DEFAULTS.minimum_gap
				)
			)
		if not cars.is_empty() and cars.back().get_instance_id() != last_id:
			last_id = cars.back().get_instance_id()
			spawns += 1
			alternating = alternating and cars.back().position.x != previous_x
			previous_x = cars.back().position.x
	_check(safe, "Traffic preserves the minimum gap at this difficulty")
	_check(bounded, "Traffic preserves the active car cap at this difficulty")
	_check(alternating, "Traffic continues alternating lanes at this difficulty")
	traffic.free()
	return spawns


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

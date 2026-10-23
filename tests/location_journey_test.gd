extends SceneTree

const MAIN: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const SEQUENCE: LocationSequence = preload("res://src/routes/tashkent_journey.tres")

var checks: int = 0
var failures: int = 0
var arrivals: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_sequence()
	_test_art()
	await _test_game()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: six locations, transitions, braking, pause, restart, banners (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_sequence() -> void:
	var journey := LocationJourney.new()
	journey.location_changed.connect(func(key: String) -> void: arrivals.append(key))
	journey.configure(GARAGE.find_route("tashkent"))
	_check(journey.current == SEQUENCE.locations[0], "Default drive starts in the mahalla")
	_check(journey.previous == null and journey.transition == 1.0, "Start has no old district")
	journey.advance(549.99)
	_check(journey.index == 0 and arrivals.size() == 1, "No early or repeated announcement")
	journey.advance(550.0)
	_check(journey.index == 1 and journey.transition == 0.0, "Chorsu enters at exactly 550 m")
	_check(journey.previous == SEQUENCE.locations[0], "Old scenery remains during entry")
	journey.advance(574.0)
	_check(is_equal_approx(journey.transition, 0.5), "Entry follows distance within the district")
	journey.advance(598.0)
	_check(journey.previous == null and journey.transition == 1.0, "Old art released after entry")
	for section in range(2, 19):
		journey.advance(section * 550.0 + 60.0)
		_check(journey.index == section % 6, "All six districts repeat in order")
		_check(journey.current == SEQUENCE.locations[section % 6], "Index chooses matching art")
	var count := arrivals.size()
	journey.advance(550.0 * 6001.0 + 24.0)
	_check(journey.index == 1 and journey.transition == 0.5, "Large steps select correct phase")
	_check(arrivals.size() == count + 1, "Skipped districts do not flood the banner")
	journey.configure(GARAGE.find_route("magic_city"))
	_check(journey.index == 5, "Magic City selection starts at Magic City")
	journey.advance(550.0)
	_check(journey.index == 0, "Magic City continues into the mahalla")
	journey.configure(GARAGE.find_route("samarkand"))
	journey.advance(100000.0)
	_check(journey.current == null and journey.previous == null, "Paid city stays static")
	_check(arrivals.back().is_empty(), "Leaving the itinerary clears its banner")
	_check(SEQUENCE.section_metres == 550.0, "Shared distance setting stays immutable")
	_check(GARAGE.find_route("magic_city").start_location == 5, "Start setting stays immutable")
	journey.free()


func _test_art() -> void:
	var names: Array[String] = []
	var textures: Array[Texture2D] = []
	_check(SEQUENCE.locations.size() == 6, "There are six different locations")
	for art in SEQUENCE.locations:
		_check(not names.has(art.name_key), "Each district has its own name")
		_check(not textures.has(art.texture), "Each district has different artwork")
		names.append(art.name_key)
		textures.append(art.texture)
		_check(art.texture.get_image().has_mipmaps(), "Scenery is mipmapped for driving size")
		_check(
			art.source_curbs.x > 0 and art.source_curbs.y < art.texture.get_width(),
			"Both sidewalks fit inside the source"
		)
		_check(art.source_curbs.y > art.source_curbs.x, "Road region has positive width")
		_check(art.source_height <= art.texture.get_height(), "Loop crop fits the source")
		for translation in CruiseHUD.TRANSLATIONS:
			_check(not translation.get_message(art.name_key).is_empty(), "All locale names exist")


func _test_game() -> void:
	var game := MAIN.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.start_run()
	game.world.player.set_physics_process(false)
	var banner := game.hud.drive.location_banner
	_check(banner.visible and banner.name_key == "location_mahalla", "Starting area appears")
	game.world.traffic._spawn_vehicle()
	var vehicle := game.world.traffic.vehicles[0]
	vehicle.position = Vector2(170, 100)
	game.score = 123
	game.distance_metres = 549.9
	game.advance(0.1)
	_check(game.world.journey.index == 1, "Actual driving crosses the boundary")
	_check(game.world.scenery.art == SEQUENCE.locations[1], "World passes new art to scenery")
	_check(game.world.scenery.previous_art == SEQUENCE.locations[0], "Entry keeps old art below")
	_check(vehicle in game.world.traffic.vehicles, "Changing district preserves live traffic")
	_check(vehicle.position.y > 100, "Traffic continues moving through the transition")
	_check(game.score == 123, "Changing scenery does not reset score")
	_check(banner.name_key == "location_chorsu" and banner.visible, "New district announced")
	var share := game.world.scenery.transition
	var offset := game.world.scenery.scroll_offset
	var remaining := banner.remaining
	game.pause_run()
	game.advance(5.0)
	_check(not banner.visible and banner.remaining == remaining, "Pause hides and freezes banner")
	_check(game.world.scenery.transition == share, "Pause freezes district entry")
	_check(game.world.scenery.scroll_offset == offset, "Pause freezes scrolling")
	game.set_language("ru")
	_check(banner.text == "Базар Чорсу", "Changing locale refreshes the current name")
	game.resume_run()
	game.world.player.set_physics_process(false)
	_check(banner.visible and banner.remaining == remaining, "Resume restores remaining banner")
	game.world.set_braking(true)
	var before := game.distance_metres
	game.advance(0.2)
	var braked_distance := game.distance_metres - before
	_check(braked_distance < 2.2, "Braking reduces distance toward the next district")
	_check(
		is_equal_approx(game.world.journey.transition, (game.distance_metres - 550.0) / 48.0),
		"Transition uses braked travel, not elapsed time"
	)
	game.hud.set_distance(game.distance_metres, 10.0)
	_check(not banner.visible, "Name expires without covering the road indefinitely")
	game.world.traffic.contacted.emit()
	game.restart_run()
	_check(game.world.journey.index == 0, "Restart begins at the selected route's first district")
	_check(game.world.scenery.previous_art == null, "Restart clears the old transition")
	_check(game.world.scenery.scroll_offset == 0.0, "Restart resets scrolling")
	_check(banner.name_key == "location_mahalla" and banner.visible, "Restart names starting area")
	game.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

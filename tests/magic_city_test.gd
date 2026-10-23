extends SceneTree

const MAIN: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const MAGIC: StreetArt = preload("res://src/scenery/magic_city_art.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_art()
	_test_scrolling()
	_test_selection_and_save()
	await _test_game()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: Magic City selection, scenery, persistence, pause, and reset (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_art() -> void:
	var route := GARAGE.find_route("magic_city")
	_check(route != null and route.street_art == MAGIC, "Magic City has its own street art")
	_check(route.price == 0 and route.points_scale == 1.0, "Scenery is free with standard scoring")
	_check(route.region_code == "01", "Magic City uses the Tashkent plate region")
	_check(route.landmarks.is_empty(), "Generated scenery has no unrelated landmark overlays")
	_check(not MAGIC.bakery_sign, "The old mahalla NON sign is not overlaid on Magic City")
	var image := MAGIC.texture.get_image()
	_check(image.has_mipmaps(), "Street texture has mipmaps for the mobile-scale view")
	_check(MAGIC.source_curbs.x > 0.0, "Left sidewalk exists")
	_check(MAGIC.source_curbs.y > MAGIC.source_curbs.x, "Road source has positive width")
	_check(MAGIC.source_curbs.y < image.get_width(), "Right sidewalk exists")
	_check(MAGIC.source_height <= image.get_height(), "The loop crop fits inside the texture")
	for city in ["tashkent", "samarkand", "bukhara", "khiva"]:
		_check(GARAGE.find_route(city).street_art == null, "Existing routes retain their artwork")


func _test_scrolling() -> void:
	var first := SceneryView.new()
	var second := SceneryView.new()
	root.add_child(first)
	root.add_child(second)
	first.configure(ROAD)
	second.configure(ROAD)
	first.set_street_art(MAGIC)
	first.advance(MAGIC.repeat_distance - 0.5)
	first.advance(1.0)
	_check(is_equal_approx(first.scroll_offset, 0.5), "New scenery wraps at its own loop length")
	first.advance(MAGIC.repeat_distance * 1000.0 + 25.0)
	_check(is_equal_approx(first.scroll_offset, 25.5), "Long frames retain the correct loop phase")
	_check(second.art == SceneryView.DEFAULT_ART, "One scene's route does not change another")
	_check(second.scroll_offset == 0.0, "Scroll state stays on each node")
	first.configure(ROAD)
	_check(
		first.art == MAGIC and first.scroll_offset == 0.0, "Restart preserves art and resets scroll"
	)
	first.set_street_art(null)
	_check(first.art == SceneryView.DEFAULT_ART, "A legacy route restores the mahalla scenery")
	_check(MAGIC.repeat_distance == 864.0, "Drawing and scrolling do not modify shared art tuning")
	first.free()
	second.free()


func _test_selection_and_save() -> void:
	var path := "user://magic_city_test_%d.json" % OS.get_process_id()
	var store := LocalProgressStore.new()
	store.save_path = path
	store.load_progress()
	var wallet := store.wallet
	_check(
		RouteRules.choose(GARAGE, store, "magic_city"), "Magic City can be chosen with no points"
	)
	_check(
		store.wallet == wallet and store.route == "magic_city", "Free selection preserves wallet"
	)
	_check(RouteRules.choose(GARAGE, store, "magic_city"), "Selecting again succeeds")
	_check(store.owned_routes.count("magic_city") == 1, "Free selection never duplicates ownership")
	var reopened := LocalProgressStore.new()
	reopened.save_path = path
	reopened.load_progress()
	_check(RouteRules.current(GARAGE, reopened).id == "magic_city", "Selection survives relaunch")
	store.free()
	reopened.free()
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _test_game() -> void:
	var game := MAIN.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.garage_action("route", "magic_city")
	_check(game.world.scenery.art == MAGIC, "Route selection reaches scenery through the world")
	_check(not game.world.landmarks.visible, "The Magic City road has no legacy landmark drawings")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.advance(0.1)
	var offset := game.world.scenery.scroll_offset
	_check(offset > 0.0, "The new street moves with actual driving")
	game.pause_run()
	game.advance(1.0)
	_check(game.world.scenery.scroll_offset == offset, "Pause freezes the new street")
	game.resume_run()
	game.world.player.set_physics_process(false)
	game.world.traffic.contacted.emit()
	game.restart_run()
	_check(game.world.scenery.art == MAGIC, "The selected street survives game over and restart")
	_check(game.world.scenery.scroll_offset == 0.0, "Restart begins at the street's start")
	game.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

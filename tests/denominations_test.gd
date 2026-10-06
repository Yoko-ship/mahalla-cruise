extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const DEFAULTS: PickupSettings = preload("res://src/pickups/default_pickups.tres")
const VALUES: Array[int] = [1000, 5000, 10000, 50000, 100000]
const POINTS: Array[int] = [1, 5, 10, 50, 100]

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalogue()
	_test_weighted_selection()
	_test_mixed_collections()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: denomination scoring, rarity, artwork, and mixed collections (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_catalogue() -> void:
	_check(DEFAULTS.som_notes.size() == 5, "Five soʻm denominations are configured")
	for index in range(VALUES.size()):
		var note := DEFAULTS.som_notes[index]
		_check(note.face_value == VALUES[index] and not note.is_dollar, "Correct soʻm face value")
		_check(DEFAULTS.points_for(note) == POINTS[index], "1,000 soʻm earns exactly one point")
		_check(note.texture != null and note.texture.get_width() > 0, "Soʻm artwork imports")
	_check(DEFAULTS.dollar_note.face_value == 1, "The dollar artwork represents a $1 note")
	_check(DEFAULTS.points_for(DEFAULTS.dollar_note) == 10, "$1 earns ten game points")
	_check(DEFAULTS.dollar_note.texture != null, "Dollar artwork imports")
	_check(DEFAULTS.som_notes[4].display_name() == "100 000 soʻm", "Large values are readable")
	_check(DEFAULTS.dollar_note.display_name() == "$1", "Dollar label includes its denomination")


func _test_weighted_selection() -> void:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for index in range(100):
		var note := DEFAULTS.select_note(false, (index + 0.5) / 100.0)
		counts[DEFAULTS.som_notes.find(note)] += 1
	_check(counts == [50, 28, 16, 5, 1], "Increasing denominations appear progressively less often")
	_check(
		DEFAULTS.select_note(false, 0.0).face_value == 1000, "First rarity interval includes zero"
	)
	_check(DEFAULTS.select_note(false, 0.5).face_value == 5000, "Rarity boundary selects next note")
	_check(DEFAULTS.select_note(false, 1.0).face_value == 100000, "Maximum roll selects last note")
	_check(
		DEFAULTS.select_note(true, 0.0) == DEFAULTS.dollar_note, "Dollar selection uses its asset"
	)
	_check(
		DEFAULTS.select_note(true, 1.0) == DEFAULTS.dollar_note,
		"Dollar is independent of soʻm roll"
	)
	var variant := DEFAULTS.duplicate() as PickupSettings
	var disabled := DEFAULTS.som_notes[0].duplicate() as BanknoteDefinition
	disabled.spawn_weight = 0.0
	variant.som_notes = [disabled, DEFAULTS.som_notes[1]]
	_check(variant.select_note(false, 0.0).face_value == 5000, "Zero-weight notes never spawn")


func _test_mixed_collections() -> void:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.pickup_settings = DEFAULTS.duplicate() as PickupSettings
	game.pickup_settings.first_spawn_distance = 1.0
	game.pickup_settings.spawn_distance = 1000.0
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	var notes: Array[BanknoteDefinition] = DEFAULTS.som_notes.duplicate()
	notes.append(DEFAULTS.dollar_note)
	var expected: int = 0
	for note in notes:
		game.pickup_settings.som_notes = [note]
		game.pickup_settings.dollar_chance = 1.0 if note.is_dollar else 0.0
		game.pickups.configure(game.road_settings, game.pickup_settings)
		game.advance(1.0 / game.road_settings.scroll_speed)
		var item: MoneyPickup = game.pickups.items.front()
		_check(item.visual.denomination == note, "Rendered note matches the spawned denomination")
		game.player.position.x = item.position.x
		game.advance(3.5)
		expected += DEFAULTS.points_for(note)
		_check(game.score == expected, "Mixed note values accumulate through actual collection")
		_check(
			(
				game.hud.pickup_label.text
				== "%s  +%d pts" % [note.display_name(), DEFAULTS.points_for(note)]
			),
			"Collection feedback identifies face value and awarded points"
		)
	_check(game.score == 176 and game.hud.score_label.text == "176 pts", "All six notes total 176")
	_check(game.som_collected == 5 and game.dollars_collected == 1, "Counts still count notes")
	_check(DEFAULTS.som_notes.size() == 5, "Spawning leaves the shared catalogue intact")
	_check(DEFAULTS.som_notes[0].spawn_weight == 50.0, "Variants leave shared rarity unchanged")
	game.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

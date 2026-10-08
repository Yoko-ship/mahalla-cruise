extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0
var _directory: String
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_directory = "user://preferences_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_absolute(_directory)
	_path = _directory.path_join("progress.json")
	_test_old_and_malformed_saves()
	_test_round_trip_and_forward_safety()
	await _test_menu_connections()
	_test_failed_write_retry()
	_test_save_warning()
	_clean_files()
	DirAccess.remove_absolute(_directory)
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: language, feedback settings, legacy saves, and retries (%d checks)" % checks)
	quit(1 if failures else 0)


func _new_store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _test_old_and_malformed_saves() -> void:
	_write({"version": 1, "stats": {"best_score": 175}})
	var store := _new_store()
	_check(store.best_score == 175 and store.language == "uz", "Old records default to Uzbek")
	_check(store.sound_enabled and store.haptics_enabled, "Missing settings use audible defaults")
	store.free()
	for invalid: Variant in [
		null, [], 42, {"language": "xx", "sound_enabled": "no"}, {"language": 5}, {"language": true}
	]:
		_write({"version": 1, "stats": {"best_score": 175}, "preferences": invalid})
		store = _new_store()
		_check(store.best_score == 175, "Malformed optional preferences never lose a record")
		_check(
			store.language == "uz" and store.sound_enabled, "Malformed settings fall back safely"
		)
		store.set_preferences("ru", false, true)
		store.load_progress()
		_check(
			store.best_score == 175 and store.language == "ru", "Damaged settings can be repaired"
		)
		store.free()


func _test_round_trip_and_forward_safety() -> void:
	_clean_files()
	_write({"version": 1, "stats": {"best_score": 175}, "preferences": {"future_option": 7}})
	var store := _new_store()
	store.set_preferences("ru", false, false)
	store.mark_driving_hint_seen()
	var saved := FileAccess.get_file_as_string(_path)
	store.set_preferences("ru", false, false)
	_check(FileAccess.get_file_as_string(_path) == saved, "Unchanged options do not rewrite saves")
	store.free()
	store = _new_store()
	_check(
		store.language == "ru" and not store.sound_enabled, "Language and sound survive relaunch"
	)
	_check(
		not store.haptics_enabled and store.driving_hint_seen, "Haptics and hint survive together"
	)
	_check(store.best_score == 175, "Preferences retain the best score")
	_check(
		ProgressData.parse(saved).preferences.future_option == 7, "Unknown settings survive writes"
	)
	store.set_preferences("invalid", true, true)
	_check(
		store.language == "ru" and not store.sound_enabled, "Invalid locale changes are rejected"
	)
	store.record_score(200)
	store.load_progress()
	_check(store.best_score == 200 and store.language == "ru", "New records preserve settings")
	store.free()
	var damaged := FileAccess.open(_path, FileAccess.WRITE)
	damaged.store_string("{broken")
	damaged.close()
	store = _new_store()
	_check(store.language == "ru" and not store.sound_enabled, "Backup restores preferences too")
	store.free()
	var future := {"version": 2, "stats": {"best_score": 900}, "preferences": {"language": "en"}}
	_write(future)
	saved = FileAccess.get_file_as_string(_path)
	store = _new_store()
	store.set_preferences("ru", false, false)
	_check(store.has_unsaved_changes, "Protected saves report session-only preferences")
	_check(
		FileAccess.get_file_as_string(_path) == saved, "Settings cannot overwrite a future schema"
	)
	store.free()
	_clean_files()


func _test_menu_connections() -> void:
	var game := _new_game()
	_check(game.hud.menu.primary_button.text == "Boshlash", "A new installation opens in Uzbek")
	var options := game.hud.menu.preferences
	await _click(options.languages.get_child(1) as Button)
	_check(
		game.hud.menu.primary_button.text == "Поехали", "Russian selection updates the start menu"
	)
	_check(
		options.languages.get_child(1).button_pressed, "The selected language remains highlighted"
	)
	await _click(options.sound_button)
	await _touch(options.languages.get_child(0) as Button)
	_check(game.hud.menu.primary_button.text == "Boshlash", "Touch selection updates the language")
	_check(not game.pickup_feedback.sound_enabled, "Menu mute reaches audio before the first drive")
	options.haptics_button.button_pressed = false
	_check(not game.pickup_feedback.haptics_enabled, "Menu vibration reaches the feedback owner")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.advance(0.2)
	var distance := game.distance_metres
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.state == CruiseGame.RunState.PAUSED, "Android Back pauses an active run")
	await _click(options.languages.get_child(2) as Button)
	_check(game.hud.menu.primary_button.text == "Resume", "Paused language switch updates actions")
	game.advance(10.0)
	_check(game.distance_metres == distance, "Changing preferences never resumes gameplay")
	await _click(game.hud.menu.primary_button)
	game.world.player.set_physics_process(false)
	_check(
		game.state == CruiseGame.RunState.PLAYING,
		"Resume remains connected after a language change"
	)
	game.free()
	game = _new_game()
	_check(
		game.hud.menu.primary_button.text == "Play", "A fresh scene restores the chosen language"
	)
	_check(not game.pickup_feedback.sound_enabled, "A fresh scene restores mute")
	_check(not game.pickup_feedback.haptics_enabled, "A fresh scene restores vibration preference")
	_check(not game.hud.menu.preferences.sound_button.button_pressed, "The menu mirrors saved mute")
	game.start_run()
	_check(not game.hud.drive.controls_label.visible, "Existing onboarding remains remembered")
	game.free()


func _test_failed_write_retry() -> void:
	var store := LocalProgressStore.new()
	store.save_path = _directory.path_join("missing/progress.json")
	store.load_progress()
	store.set_preferences("en", false, true)
	_check(store.language == "en" and store.has_unsaved_changes, "Failed settings stay in memory")
	DirAccess.make_dir_absolute(_directory.path_join("missing"))
	store.set_preferences("en", false, true)
	_check(not store.has_unsaved_changes, "Repeating a choice retries an unsaved write")
	store.load_progress()
	_check(store.language == "en" and not store.sound_enabled, "Retried settings survive reload")
	DirAccess.remove_absolute(store.save_path)
	DirAccess.remove_absolute(_directory.path_join("missing"))
	store.free()


func _test_save_warning() -> void:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	var store := game.get_node("Progress") as LocalProgressStore
	store.save_path = _directory.path_join("absent/progress.json")
	root.add_child(game)
	game.set_process(false)
	game.set_language("ru")
	_check(game.hud.menu.preferences.save_warning.visible, "A failed save is visible in the menu")
	_check(game.hud.menu.primary_button.text == "Поехали", "A failed save does not block play")
	DirAccess.make_dir_absolute(_directory.path_join("absent"))
	game.set_language("ru")
	_check(
		not game.hud.menu.preferences.save_warning.visible, "Successful retry clears the warning"
	)
	DirAccess.remove_absolute(store.save_path)
	DirAccess.remove_absolute(_directory.path_join("absent"))
	game.free()


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	root.add_child(game)
	game.set_process(false)
	game.world.player.set_physics_process(false)
	return game


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _touch(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _write(document: Dictionary) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()


func _clean_files() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

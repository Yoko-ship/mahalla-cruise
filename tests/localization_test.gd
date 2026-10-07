extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const ENGLISH: Translation = preload("res://src/ui/text_en.tres")
const UZBEK: Translation = preload("res://src/ui/text_uz.tres")
const RUSSIAN: Translation = preload("res://src/ui/text_ru.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalogues()
	for locale in ProgressData.LANGUAGES:
		await _test_language(locale)
	if failures == 0:
		print("PASS: complete translations, dynamic text, and menu layout (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_catalogues() -> void:
	var keys := ENGLISH.get_message_list()
	for catalogue in [UZBEK, RUSSIAN]:
		_check(catalogue.get_message_count() == keys.size(), "Every language has the complete UI")
		for key in keys:
			var text := String(catalogue.get_message(key))
			_check(not text.is_empty(), "Translation exists for %s in %s" % [key, catalogue.locale])
			var source := String(ENGLISH.get_message(key))
			_check(
				text.count("%d") == source.count("%d") and text.count("%s") == source.count("%s"),
				"Translated placeholders match for %s" % key
			)


func _test_language(locale: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(432, 768)
	root.add_child(view)
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	view.add_child(game)
	game.set_process(false)
	game.set_language(locale)
	# Inspect the Android options layout without claiming physical-device validation.
	game.hud.menu.preferences.haptics_button.show()
	await _settle()
	var card := game.hud.menu.get_node("Center/Card") as Control
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Start card fits: " + locale)
	_check(game.hud.menu.instructions.text.contains("\n"), "Instructions use a real line break")
	_check(game.hud.menu.primary_button.size.y >= 48, "Primary touch target is at least 48 pixels")
	game.start_run()
	game.player.set_physics_process(false)
	game.hud.set_score(175, 5, 1)
	game.hud.show_pickup(100, "100 000 soʻm")
	_check(not game.hud.score_label.text.contains("points_short"), "Scores use translated values")
	if locale == "uz":
		_check(game.hud.score_label.text == "175 ball", "Uzbek score is readable")
	elif locale == "ru":
		_check(
			game.hud.pickup_label.text == "100 000 сум  +100 очк.", "Russian pickup is localized"
		)
	game.hud.set_score(ProgressData.MAX_SCORE, 1, 1)
	game.hud.set_best(ProgressData.MAX_SCORE)
	await _settle()
	for label: Label in [game.hud.score_label, game.hud.best_label]:
		var width := (
			label
			. get_theme_font("font")
			. get_string_size(
				label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
			)
			. x
		)
		_check(width <= label.size.x, "Large HUD values fit: " + locale)
	game.pause_run()
	await _settle()
	_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Pause card fits: " + locale)
	game.resume_run()
	game.traffic.contacted.emit()
	game.hud.set_score(ProgressData.MAX_SCORE, 999999, 999999)
	game.hud.set_best(ProgressData.MAX_SCORE, true, true)
	await _settle()
	var results := game.hud.game_over_panel.get_node("Card") as Control
	_check(
		Rect2(0, 0, 432, 768).encloses(results.get_global_rect()), "Maximum results fit: " + locale
	)
	_check(
		results.get_global_rect().encloses(
			game.hud.game_over_panel.restart_button.get_global_rect()
		),
		"Restart fits"
	)
	_check(
		game.hud.game_over_panel.best_result.get_line_count() >= 2,
		"Long unsaved records wrap in their card"
	)
	view.free()


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

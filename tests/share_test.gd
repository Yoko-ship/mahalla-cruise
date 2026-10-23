extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_urls()
	await _test_results()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: Telegram share links, results button, text, and layout (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_urls() -> void:
	var text := "Men 120 ball yigʻdim! 🚐"
	var app := ShareRules.app_url(text)
	_check(app.begins_with("tg://msg?text="), "The Telegram app share screen")
	_check(not app.contains(" ") and app.substr(14).uri_decode() == text, "Text is encoded")
	_check(ShareRules.web_url(text).begins_with("https://t.me/share/url?url="), "Web fallback")
	_check(ShareRules.open(text) == app, "Headless runs build the link without opening it")


func _test_results() -> void:
	for locale in ProgressData.LANGUAGES:
		var view := SubViewport.new()
		view.size = Vector2i(432, 768)
		root.add_child(view)
		var game := MAIN_SCENE.instantiate() as CruiseGame
		game.easy_mode = false  # Exercise the original Challenge rules.
		(game.get_node("Progress") as LocalProgressStore).save_path = ""
		view.add_child(game)
		game.set_process(false)
		game.set_language(locale)
		game.start_run()
		game.world.player.set_physics_process(false)
		game.score = 345
		game._show_score()
		game.distance_metres = 1234.5
		game.world.traffic.contacted.emit()
		await _settle()
		var panel := game.hud.game_over_panel
		_check(panel.share_button.visible and panel.share_button.size.y >= 48, "Share: " + locale)
		_check(not panel.share_button.text.contains("share"), "Translated: " + locale)
		var shared: Array[String] = []
		game.hud.share_requested.connect(func(text: String) -> void: shared.append(text))
		panel.share_button.pressed.emit()
		_check(shared.size() == 1, "Share asks main to open Telegram: " + locale)
		_check(shared[0].contains("345") and shared[0].contains("1234"), "Score and distance")
		_check(shared[0].contains("Mahalla Cruise"), "The game is named: " + locale)
		game.hud.settings = game.hud.settings.duplicate() as HUDSettings
		game.hud.settings.share_link = "https://t.me/mahalla_cruise"
		panel.share_button.pressed.emit()
		_check(shared[1].ends_with("\nhttps://t.me/mahalla_cruise"), "A configured link is added")
		game.hud.set_score(ProgressData.MAX_SCORE, 999999, 999999)
		game.hud.set_best(ProgressData.MAX_SCORE, true, true)
		await _settle()
		var card := panel.get_node("Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Results fit: " + locale)
		_check(
			card.get_global_rect().encloses(panel.share_button.get_global_rect()),
			"Share fits the card: " + locale
		)
		view.free()


func _settle() -> void:
	for _frame in range(3):
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const WHEEL: WheelSettings = preload("res://src/wheel/default_wheel.tres")
const DAY := "2026-10-12"

var failures: int = 0
var checks: int = 0
var _path: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://wheel_test_%d.json" % Time.get_ticks_usec()
	_test_settings()
	_test_rules()
	await _test_screen_and_boost()
	await _test_layout()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: lucky wheel spins, prizes, drive boosts, saving, and screen (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_settings() -> void:
	_check(WHEEL.size() == 8, "Eight segments")
	_check(WHEEL.colors.size() == WHEEL.size(), "Every segment has a colour")
	_check(WHEEL.pick(0.0) == 0, "The lowest roll lands on the first segment")
	_check(WHEEL.pick(0.999) == WHEEL.size() - 1, "The highest roll lands on the jackpot")
	var counts := {}
	for step in range(1000):
		var index := WHEEL.pick(step / 1000.0)
		counts[index] = counts.get(index, 0) + 1
	_check(counts.size() == WHEEL.size(), "Every segment can be won")
	_check(counts[7] < counts[0], "The 500 jackpot is rarer than 25")


func _test_rules() -> void:
	var store := LocalProgressStore.new()
	store.save_path = ""
	store.load_progress()
	_check(WheelRules.can_spin(store, DAY), "A new player may spin")
	_check(WheelRules.spin(WHEEL, store, DAY, 0.0), "Spinning works")
	_check(store.wallet == 25 and store.next_boost == "", "Points go to the wallet")
	_check(not WheelRules.spin(WHEEL, store, DAY, 0.5), "Only one spin a day")
	_check(WheelRules.view(store, DAY) == {"available": false, "prize": 0, "boost": ""}, "View")
	_check(WheelRules.spin(WHEEL, store, "2026-10-13", 0.25), "A new day spins again")
	_check(store.next_boost == "magnet" and store.wallet == 25, "A power-up waits for a drive")
	_check(WheelRules.view(store, "2026-10-14").prize == -1, "Yesterday's prize is not today's")
	_check(WheelRules.take_boost(store) == "magnet", "A drive takes the power-up")
	_check(store.next_boost == "" and WheelRules.take_boost(store) == "", "Only once")
	store.free()


func _test_screen_and_boost() -> void:
	var game := _new_game()
	var menu := game.hud.menu
	_check(menu.gift_button.visible and menu.gift_button.text == "Lucky!", "Start shows the wheel")
	_check(menu.is_processing(), "The gift pulses while today's spin is free")
	menu.gift_button.pressed.emit()
	var wheel := game.hud.wheel_menu
	_check(wheel.visible and not menu.visible, "The wheel screen opens")
	_check(
		wheel.title.text == "Lucky wheel" and wheel.result.text == "One free spin every day!",
		"Wheel text"
	)
	wheel.spin_button.pressed.emit()
	_check(game.progress.wheel_day == DailyTasks.today(), "The spin is saved at once")
	_check(wheel.spinning and wheel.spin_button.disabled, "The wheel turns")
	wheel._process(WHEEL.spin_seconds + 0.1)
	var prize := game.progress.wheel_prize
	_check(not wheel.spinning, "The wheel stops")
	_check(
		is_equal_approx(
			fposmod(wheel.wheel.angle, TAU), fposmod(wheel.wheel.angle_for(prize), TAU)
		),
		"It stops on the prize"
	)
	_check(wheel.spin_button.text == "Back tomorrow", "Tomorrow for the next spin")
	if WHEEL.kinds[prize] == "points":
		_check(wheel.result.text == "You won %d points!" % WHEEL.amounts[prize], "Points won")
	else:
		_check(wheel.result.text.contains("for your next drive"), "A power-up won")
	wheel.close()
	_check(menu.visible and not menu.is_processing(), "Back to the start; no more pulsing")
	game.free()
	# A waiting power-up survives relaunch, shows on the start card, and starts one drive.
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	store.update(func() -> void: store.next_boost = "shield")
	store.free()
	game = _new_game()
	_check(game.progress.next_boost == "shield", "The power-up survives relaunch")
	_check(game.hud.menu.boost_label.visible, "The start card shows it")
	_check(game.hud.menu.boost_label.text == "Bonus: Shield", "Named")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(game.world.pickups.effects.shield, "The drive starts with the shield")
	_check(game.hud.drive.power_up_bar.active_kinds() == ["shield"], "Its chip shows")
	_check(game.hud.drive.pickup_label.text == "Shield!", "Announced")
	_check(game.progress.next_boost == "", "It is used up")
	game.world.traffic.contacted.emit()
	_check(not game.is_game_over, "The wheel's shield absorbs a crash")
	game.free()


func _test_layout() -> void:
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
		game.progress.update(func() -> void: game.progress.next_boost = "double")
		game.garage_action("wheel", "")
		await _settle()
		var start := game.hud.menu.get_node("Center/Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(start.get_global_rect()), "Start fits: " + locale)
		var gift := game.hud.menu.gift_button
		_check(start.get_global_rect().encloses(gift.get_global_rect()), "Gift fits: " + locale)
		_check(gift.size.y >= 48, "Gift touch target: " + locale)
		_check(
			not gift.get_global_rect().intersects(game.hud.menu.boost_label.get_global_rect()),
			"The bonus and the gift do not overlap: " + locale
		)
		game.hud.menu.gift_button.pressed.emit()
		game.hud.wheel_menu._process(10.0)
		await _settle()
		var card := game.hud.wheel_menu.get_node("Center/Card") as Control
		_check(Rect2(0, 0, 432, 768).encloses(card.get_global_rect()), "Wheel fits: " + locale)
		_check(not game.hud.wheel_menu.result.text.contains("wheel_"), "Translated: " + locale)
		view.free()


func _new_game() -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	game.easy_mode = false  # Exercise the original Challenge rules.
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	root.add_child(game)
	game.set_process(false)
	game.set_language("en")
	return game


func _settle() -> void:
	for _frame in range(3):
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

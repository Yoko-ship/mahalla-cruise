class_name CruiseHUD
extends CanvasLayer
## Displays values supplied by the game. Does not look up or change gameplay state.
## The drive overlay shows road-time values; menus and results are separate children.

signal restart_requested
signal play_requested
signal pause_requested
signal resume_requested
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)
signal language_selected(locale: String)
signal garage_requested
## A shop action for main (see GarageRules.apply): "car", "paint", "upgrade", "route",
## "plate", "used", or "repair".
signal garage_action(action: String, id: String)
signal music_toggled(enabled: bool)
signal horn_pressed
signal brake_changed(held: bool)

const TRANSLATIONS: Array[Translation] = [
	preload("res://src/ui/text_uz.tres"),
	preload("res://src/ui/text_ru.tres"),
	preload("res://src/ui/text_en.tres")
]

@export var settings: HUDSettings

var _game_over: bool = false
var _best: int = 0
var _record: bool = false
var _unsaved: bool = false
var _sound: bool = true
var _haptics: bool = true
var _music: bool = true

@onready var drive: DriveOverlay = $Drive
@onready var game_over_panel: ResultsPanel = $GameOver
@onready var menu: RunMenu = $RunMenu
@onready var garage_menu: GarageMenu = $GarageMenu
@onready var daily_menu: DailyMenu = $DailyMenu
@onready var market_menu: MarketMenu = $MarketMenu


func _ready() -> void:
	assert(settings != null, "HUD requires HUDSettings")
	for translation in TRANSLATIONS:
		TranslationServer.add_translation(translation)
	game_over_panel.restart_pressed.connect(func() -> void: restart_requested.emit())
	game_over_panel.garage_pressed.connect(func() -> void: garage_requested.emit())
	menu.primary_pressed.connect(_on_menu_primary)
	drive.pause_pressed.connect(func() -> void: pause_requested.emit())
	drive.horn_pressed.connect(func() -> void: horn_pressed.emit())
	drive.brake_changed.connect(func(held: bool) -> void: brake_changed.emit(held))
	menu.sound_toggled.connect(func(enabled: bool) -> void: sound_toggled.emit(enabled))
	menu.haptics_toggled.connect(func(enabled: bool) -> void: haptics_toggled.emit(enabled))
	menu.language_selected.connect(func(locale: String) -> void: language_selected.emit(locale))
	menu.music_toggled.connect(func(enabled: bool) -> void: music_toggled.emit(enabled))
	menu.garage_pressed.connect(func() -> void: garage_requested.emit())
	menu.tasks_pressed.connect(_show_tasks)
	garage_menu.action_chosen.connect(garage_action.emit)
	market_menu.action_chosen.connect(garage_action.emit)
	menu.route_chosen.connect(func(id: String) -> void: garage_action.emit("route", id))
	garage_menu.market_pressed.connect(_show_market)
	market_menu.closed.connect(garage_menu.open)
	garage_menu.closed.connect(func() -> void: menu.show_start(_best))
	daily_menu.closed.connect(func() -> void: menu.show_start(_best))


func set_playfield_offset(offset: Vector2) -> void:
	drive.set_playfield_offset(offset)


func show_start(best: int) -> void:
	drive.set_active(false)
	menu.show_start(best)


func set_garage(catalogue: GarageCatalogue, view: Dictionary) -> void:
	garage_menu.set_state(catalogue, view)
	market_menu.set_state(catalogue, view)
	menu.set_car(catalogue.find(view.selected).texture, view.colors[view.selected])
	menu.set_garage(catalogue.routes, view)


func show_garage() -> void:
	drive.set_active(false)
	menu.close()
	garage_menu.open()


func set_daily(entries: Array[Dictionary], achievements: Array[Dictionary] = []) -> void:
	daily_menu.set_entries(entries, achievements)


func _show_market() -> void:
	garage_menu.hide()
	market_menu.open()


func _show_tasks() -> void:
	drive.set_active(false)
	menu.close()
	daily_menu.open()


func leave_results() -> void:
	# Game over returns to the start screen without beginning a new drive.
	_game_over = false
	drive.dismiss_text()
	game_over_panel.close()
	drive.start_hint(0.0)
	drive.set_distance(0.0)


func begin_run(first_hint: bool) -> void:
	menu.close()
	drive.set_active(true)
	drive.start_hint(settings.first_hint_seconds if first_hint else 0.0)


func show_paused(points: int, metres: float) -> void:
	drive.dismiss_text()
	drive.set_active(false)
	menu.show_pause(points, metres)


func resume_run() -> void:
	menu.close()
	drive.set_active(true)


func _on_menu_primary() -> void:
	if menu.is_pause:
		resume_requested.emit()
	else:
		play_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if market_menu.visible:
		market_menu.close()
	elif garage_menu.visible:
		garage_menu.close()
	elif daily_menu.visible:
		daily_menu.close()
	elif menu.visible and menu.is_pause:
		resume_requested.emit()
	elif not menu.visible and not _game_over:
		pause_requested.emit()
	get_viewport().set_input_as_handled()


## delta advances the first-drive hint; main passes it only while driving.
func set_distance(metres: float, delta: float = 0.0) -> void:
	drive.set_distance(metres, delta)


func set_feedback_options(
	sound: bool, haptics: bool, unsaved: bool = false, music: bool = true
) -> void:
	_sound = sound
	_haptics = haptics
	_music = music
	set_best(_best, _record, unsaved)
	menu.set_options(sound, haptics, unsaved, music)


func refresh_text() -> void:
	drive.refresh_text()
	game_over_panel.refresh_text()
	menu.refresh_text()
	garage_menu.refresh_text()
	market_menu.refresh_text()
	daily_menu.refresh_text()
	menu.set_options(_sound, _haptics, _unsaved, _music)


func set_score(points: int, som_count: int, dollar_count: int, close_calls: int = 0) -> void:
	drive.set_score(points)
	game_over_panel.set_score(points, som_count, dollar_count, close_calls)


func set_best(points: int, new_record: bool = false, unsaved: bool = false) -> void:
	_best = points
	_record = new_record
	_unsaved = unsaved
	drive.set_best(points)
	game_over_panel.set_best(points, new_record, unsaved)


func show_pickup(points: int, denomination_label: String) -> void:
	if _game_over:
		return
	if TranslationServer.get_locale().begins_with("ru"):
		denomination_label = denomination_label.replace("soʻm", "сум")
	drive.show_text(tr("pickup") % [denomination_label, points])


## A brief road message: close calls, power-ups, hazards, fuel, nightfall, cameras, taxi.
func show_feedback(text_key: String, values: Array = []) -> void:
	if not _game_over:
		drive.show_text(tr(text_key) % values if not values.is_empty() else tr(text_key))


func set_power_ups(view: Dictionary) -> void:
	drive.set_power_ups(view)


## Fuel, speed and camera limit, and taxi ride, every frame (see DriveWorld).
func set_dashboard(view: Dictionary) -> void:
	drive.set_dashboard(view)


func show_game_over(
	metres: float,
	crash_kind: String,
	earned: int,
	wallet: int,
	task_rewards: Array[int],
	achievement_rewards: Array[int] = []
) -> void:
	game_over_panel.set_wallet(earned, wallet, task_rewards, achievement_rewards)
	_game_over = true
	drive.dismiss_text()
	drive.set_active(false)
	drive.set_distance(metres)
	game_over_panel.open(metres, crash_kind)


func reset_run() -> void:
	_game_over = false
	drive.dismiss_text()
	game_over_panel.close()
	begin_run(false)
	drive.set_distance(0.0)

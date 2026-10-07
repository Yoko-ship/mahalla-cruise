class_name CruiseHUD
extends CanvasLayer
## Displays values supplied by the game. Does not look up or change gameplay state.

signal restart_requested
signal play_requested
signal pause_requested
signal resume_requested
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)
signal language_selected(locale: String)
signal garage_requested
signal car_chosen(id: String)

const TRANSLATIONS: Array[Translation] = [
	preload("res://src/ui/text_uz.tres"),
	preload("res://src/ui/text_ru.tres"),
	preload("res://src/ui/text_en.tres")
]

@export var settings: HUDSettings

var _game_over: bool = false
var _hint_remaining: float = 0.0
var _metres: float = 0.0
var _points: int = 0
var _best: int = 0
var _record: bool = false
var _unsaved: bool = false
var _sound: bool = true
var _haptics: bool = true
var _playfield_offset := Vector2.ZERO

@onready var distance_label: Label = $Distance
@onready var game_over_panel: ResultsPanel = $GameOver
@onready var controls_label: Label = $Controls
@onready var score_label: Label = $Score
@onready var pickup_label: FeedbackPopup = $PickupFeedback
@onready var best_label: Label = $Best
@onready var menu: RunMenu = $RunMenu
@onready var pause_button: Button = $Pause
@onready var garage_menu: GarageMenu = $GarageMenu
@onready var daily_menu: DailyMenu = $DailyMenu


func _ready() -> void:
	assert(settings != null, "HUD requires HUDSettings")
	for translation in TRANSLATIONS:
		TranslationServer.add_translation(translation)
	game_over_panel.restart_pressed.connect(func() -> void: restart_requested.emit())
	game_over_panel.garage_pressed.connect(func() -> void: garage_requested.emit())
	menu.primary_pressed.connect(_on_menu_primary)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	menu.sound_toggled.connect(func(enabled: bool) -> void: sound_toggled.emit(enabled))
	menu.haptics_toggled.connect(func(enabled: bool) -> void: haptics_toggled.emit(enabled))
	menu.language_selected.connect(func(locale: String) -> void: language_selected.emit(locale))
	menu.garage_pressed.connect(func() -> void: garage_requested.emit())
	garage_menu.car_chosen.connect(func(id: String) -> void: car_chosen.emit(id))
	garage_menu.closed.connect(func() -> void: menu.show_start(_best))
	menu.tasks_pressed.connect(_show_tasks)
	daily_menu.closed.connect(func() -> void: menu.show_start(_best))


func set_playfield_offset(offset: Vector2) -> void:
	var shift := offset - _playfield_offset
	for control: Control in [
		$Title, distance_label, score_label, best_label, pause_button, controls_label, pickup_label
	]:
		control.position += shift
	pickup_label.base_y += shift.y
	_playfield_offset = offset


func show_start(best: int) -> void:
	_set_gameplay_visible(false)
	menu.show_start(best)


func set_garage(
	catalogue: GarageCatalogue, owned: Array[String], selected: String, wallet: int
) -> void:
	garage_menu.set_state(catalogue, owned, selected, wallet)
	menu.set_car_texture(catalogue.find(selected).texture)


func show_garage() -> void:
	_set_gameplay_visible(false)
	menu.close()
	garage_menu.open()


func set_daily(entries: Array[Dictionary]) -> void:
	daily_menu.set_entries(entries)


func _show_tasks() -> void:
	_set_gameplay_visible(false)
	menu.close()
	daily_menu.open()


func leave_results() -> void:
	# Game over returns to the start screen without beginning a new drive.
	_game_over = false
	pickup_label.dismiss()
	game_over_panel.close()
	_hint_remaining = 0.0
	set_distance(0.0)


func show_wallet_result(earned: int, wallet: int, task_rewards: Array[int] = []) -> void:
	game_over_panel.set_wallet(earned, wallet, task_rewards)


func begin_run(first_hint: bool) -> void:
	menu.close()
	_set_gameplay_visible(true)
	_hint_remaining = settings.first_hint_seconds if first_hint else 0.0
	controls_label.text = tr("hint").replace("\\n", "\n")
	controls_label.visible = _hint_remaining > 0.0


func advance_hint(delta: float) -> void:
	_hint_remaining = maxf(0.0, _hint_remaining - delta)
	controls_label.visible = _hint_remaining > 0.0


func show_paused(points: int, metres: float) -> void:
	pickup_label.dismiss()
	_set_gameplay_visible(false)
	menu.show_pause(points, metres)


func resume_run() -> void:
	menu.close()
	_set_gameplay_visible(true)
	controls_label.visible = _hint_remaining > 0.0


func _set_gameplay_visible(active: bool) -> void:
	for control: Control in [$Title, distance_label, score_label, best_label, pause_button]:
		control.visible = active
	controls_label.visible = active and _hint_remaining > 0.0


func _on_menu_primary() -> void:
	if menu.is_pause:
		resume_requested.emit()
	else:
		play_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if garage_menu.visible:
		garage_menu.close()
	elif daily_menu.visible:
		daily_menu.close()
	elif menu.visible and menu.is_pause:
		resume_requested.emit()
	elif not menu.visible and not _game_over:
		pause_requested.emit()
	get_viewport().set_input_as_handled()


func set_distance(metres: float) -> void:
	_metres = metres
	var text := tr("distance") % int(metres)
	if distance_label.text != text:
		distance_label.text = text
		_fit_value(distance_label, 21, 89.0)


func set_feedback_options(sound: bool, haptics: bool, unsaved: bool = false) -> void:
	_sound = sound
	_haptics = haptics
	set_best(_best, _record, unsaved)
	menu.set_options(sound, haptics, unsaved)


func refresh_text() -> void:
	set_distance(_metres)
	score_label.text = tr("points_short") % _points
	_fit_value(score_label, 19, 116.0)
	best_label.text = tr("best") % _best
	_fit_value(best_label, 15, 144.0)
	game_over_panel.refresh_text()
	controls_label.text = tr("hint").replace("\\n", "\n")
	menu.refresh_text()
	garage_menu.refresh_text()
	daily_menu.refresh_text()
	menu.set_options(_sound, _haptics, _unsaved)
	pickup_label.dismiss()


func set_score(points: int, som_count: int, dollar_count: int, close_calls: int = 0) -> void:
	_points = points
	score_label.text = tr("points_short") % points
	_fit_value(score_label, 19, 116.0)
	game_over_panel.set_score(points, som_count, dollar_count, close_calls)


func set_best(points: int, new_record: bool = false, unsaved: bool = false) -> void:
	_best = points
	_record = new_record
	_unsaved = unsaved
	best_label.text = tr("best") % points
	_fit_value(best_label, 15, 144.0)
	game_over_panel.set_best(points, new_record, unsaved)


func _fit_value(label: Label, font_size: int, width: float) -> void:
	var font := label.get_theme_font("font")
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted := mini(font_size, floori(font_size * width / maxf(text_width, 1.0)))
	label.add_theme_font_size_override("font_size", maxi(10, fitted))


func show_pickup(points: int, denomination_label: String) -> void:
	if _game_over:
		return
	if TranslationServer.get_locale().begins_with("ru"):
		denomination_label = denomination_label.replace("soʻm", "сум")
	pickup_label.play(tr("pickup") % [denomination_label, points])


func show_near_miss(points: int, combo: int) -> void:
	if _game_over:
		return
	var text := tr("near_miss") % points
	if combo > 1:
		text = tr("near_miss_combo") % [combo, points]
	pickup_label.play(text)


func show_game_over(metres: float, crash_kind: String = "car") -> void:
	_game_over = true
	pickup_label.dismiss()
	_set_gameplay_visible(false)
	set_distance(metres)
	game_over_panel.open(metres, crash_kind)
	pause_button.hide()
	controls_label.hide()


func reset_run() -> void:
	_game_over = false
	pickup_label.dismiss()
	game_over_panel.close()
	begin_run(false)
	set_distance(0.0)

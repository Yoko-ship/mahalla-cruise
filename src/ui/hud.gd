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

const TRANSLATIONS: Array[Translation] = [
	preload("res://src/ui/text_uz.tres"),
	preload("res://src/ui/text_ru.tres"),
	preload("res://src/ui/text_en.tres")
]

@export var settings: HUDSettings

var _game_over: bool = false
var _pickup_tween: Tween
var _hint_remaining: float = 0.0
var _metres: float = 0.0
var _points: int = 0
var _som: int = 0
var _dollars: int = 0
var _best: int = 0
var _record: bool = false
var _unsaved: bool = false
var _sound: bool = true
var _haptics: bool = true
var _playfield_offset := Vector2.ZERO

@onready var distance_label: Label = $Distance
@onready var game_over_panel: Control = $GameOver
@onready var result_label: Label = $GameOver/Card/Margin/Content/Result
@onready var restart_button: Button = $GameOver/Card/Margin/Content/Restart
@onready var controls_label: Label = $Controls
@onready var score_label: Label = $Score
@onready var pickup_label: Label = $PickupFeedback
@onready var score_result: Label = $GameOver/Card/Margin/Content/ScoreResult
@onready var money_result: Label = $GameOver/Card/Margin/Content/MoneyResult
@onready var best_label: Label = $Best
@onready var best_result: Label = $GameOver/Card/Margin/Content/BestResult
@onready var menu: RunMenu = $RunMenu
@onready var pause_button: Button = $Pause


func _ready() -> void:
	assert(settings != null, "HUD requires HUDSettings")
	for translation in TRANSLATIONS:
		TranslationServer.add_translation(translation)
	restart_button.pressed.connect(_on_restart_pressed)
	menu.primary_pressed.connect(_on_menu_primary)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	menu.sound_toggled.connect(_on_sound_toggled)
	menu.haptics_toggled.connect(_on_haptics_toggled)
	menu.language_selected.connect(func(locale: String) -> void: language_selected.emit(locale))


func set_playfield_offset(offset: Vector2) -> void:
	var shift := offset - _playfield_offset
	for control: Control in [
		$Title, distance_label, score_label, best_label, pause_button, controls_label, pickup_label
	]:
		control.position += shift
	_playfield_offset = offset


func show_start(best: int) -> void:
	_set_gameplay_visible(false)
	menu.show_start(best)


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
	_clear_pickup_feedback()
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
	if menu.visible and menu.is_pause:
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
	set_score(_points, _som, _dollars)
	set_best(_best, _record, _unsaved)
	result_label.text = tr("travelled") % int(_metres)
	controls_label.text = tr("hint").replace("\\n", "\n")
	menu.refresh_text()
	menu.set_options(_sound, _haptics, _unsaved)
	_clear_pickup_feedback()


func _on_sound_toggled(enabled: bool) -> void:
	sound_toggled.emit(enabled)


func _on_haptics_toggled(enabled: bool) -> void:
	haptics_toggled.emit(enabled)


func set_score(points: int, som_count: int, dollar_count: int) -> void:
	_points = points
	_som = som_count
	_dollars = dollar_count
	score_label.text = tr("points_short") % points
	_fit_value(score_label, 19, 116.0)
	score_result.text = tr("points") % points
	money_result.text = tr("notes") % [som_count, dollar_count]


func set_best(points: int, new_record: bool = false, unsaved: bool = false) -> void:
	_best = points
	_record = new_record
	_unsaved = unsaved
	best_label.text = tr("best") % points
	_fit_value(best_label, 15, 144.0)
	best_result.text = tr("new_best" if new_record else "best") % points
	if unsaved:
		best_result.text += "\n" + tr("unsaved").strip_edges()


func _fit_value(label: Label, font_size: int, width: float) -> void:
	var font := label.get_theme_font("font")
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted := mini(font_size, floori(font_size * width / maxf(text_width, 1.0)))
	label.add_theme_font_size_override("font_size", maxi(10, fitted))


func show_pickup(points: int, denomination_label: String) -> void:
	if _game_over:
		return
	_clear_pickup_feedback()
	if TranslationServer.get_locale().begins_with("ru"):
		denomination_label = denomination_label.replace("soʻm", "сум")
	pickup_label.text = tr("pickup") % [denomination_label, points]
	pickup_label.position.y = 510.0 + _playfield_offset.y
	pickup_label.modulate.a = 1.0
	pickup_label.show()
	_pickup_tween = create_tween().set_parallel(true)
	_pickup_tween.tween_property(pickup_label, "position:y", 486.0 + _playfield_offset.y, 0.85)
	_pickup_tween.tween_property(pickup_label, "modulate:a", 0.0, 0.45).set_delay(0.4)


func show_game_over(metres: float) -> void:
	_game_over = true
	_clear_pickup_feedback()
	_set_gameplay_visible(false)
	set_distance(metres)
	result_label.text = tr("travelled") % int(metres)
	game_over_panel.show()
	pause_button.hide()
	controls_label.hide()
	restart_button.grab_focus()


func reset_run() -> void:
	_game_over = false
	_clear_pickup_feedback()
	game_over_panel.hide()
	restart_button.release_focus()
	begin_run(false)
	set_distance(0.0)


func _clear_pickup_feedback() -> void:
	if _pickup_tween != null:
		_pickup_tween.kill()
		_pickup_tween = null
	pickup_label.hide()


func _on_restart_pressed() -> void:
	restart_requested.emit()

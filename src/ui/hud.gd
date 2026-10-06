class_name CruiseHUD
extends CanvasLayer
## Displays values supplied by the game. Does not look up or change gameplay state.

signal restart_requested
signal play_requested
signal pause_requested
signal resume_requested
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)

@export var settings: HUDSettings

var _game_over: bool = false
var _pickup_tween: Tween
var _hint_remaining: float = 0.0

@onready var distance_label: Label = $Distance
@onready var game_over_panel: Control = $GameOver
@onready var result_label: Label = $GameOver/Card/Margin/Content/Result
@onready var restart_button: Button = $GameOver/Card/Margin/Content/Restart
@onready var controls_label: Label = $Controls
@onready var score_label: Label = $Score
@onready var pickup_label: Label = $PickupFeedback
@onready var score_result: Label = $GameOver/Card/Margin/Content/ScoreResult
@onready var money_result: Label = $GameOver/Card/Margin/Content/MoneyResult
@onready var sound_button: Button = $SoundToggle
@onready var haptics_button: Button = $HapticsToggle
@onready var best_label: Label = $Best
@onready var best_result: Label = $GameOver/Card/Margin/Content/BestResult
@onready var menu: RunMenu = $RunMenu
@onready var pause_button: Button = $Pause


func _ready() -> void:
	assert(settings != null, "HUD requires HUDSettings")
	restart_button.pressed.connect(_on_restart_pressed)
	menu.primary_pressed.connect(_on_menu_primary)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	sound_button.toggled.connect(_on_sound_toggled)
	haptics_button.toggled.connect(_on_haptics_toggled)
	haptics_button.visible = OS.has_feature("android")
	if not OS.has_feature("android"):
		pause_button.position.y = 132.0


func show_start(best: int) -> void:
	_set_gameplay_visible(false)
	menu.show_start(best)


func begin_run(first_hint: bool) -> void:
	menu.close()
	_set_gameplay_visible(true)
	_hint_remaining = settings.first_hint_seconds if first_hint else 0.0
	controls_label.text = "Drag to steer\nCollect money · Avoid cars"
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
	for control: Control in [
		$Title, distance_label, score_label, best_label, sound_button, pause_button
	]:
		control.visible = active
	haptics_button.visible = active and OS.has_feature("android")
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
	distance_label.text = "%d m" % int(metres)


func set_feedback_options(sound: bool, haptics: bool) -> void:
	sound_button.set_pressed_no_signal(sound)
	haptics_button.set_pressed_no_signal(haptics)
	sound_button.text = "Sound on" if sound else "Sound off"
	haptics_button.text = "Vibration on" if haptics else "Vibration off"


func _on_sound_toggled(enabled: bool) -> void:
	sound_toggled.emit(enabled)


func _on_haptics_toggled(enabled: bool) -> void:
	haptics_toggled.emit(enabled)


func set_score(points: int, som_count: int, dollar_count: int) -> void:
	score_label.text = "%d pts" % points
	score_result.text = "%d points" % points
	money_result.text = "soʻm × %d    ·    $ × %d" % [som_count, dollar_count]


func set_best(points: int, new_record: bool = false, unsaved: bool = false) -> void:
	best_label.text = "Best: %d" % points
	var prefix := "New best!" if new_record else "Best:"
	best_result.text = "%s %d" % [prefix, points]
	if unsaved:
		best_result.text += " (unsaved)"


func show_pickup(points: int, denomination_label: String) -> void:
	if _game_over:
		return
	_clear_pickup_feedback()
	pickup_label.text = "%s  +%d pts" % [denomination_label, points]
	pickup_label.position.y = 510.0
	pickup_label.modulate.a = 1.0
	pickup_label.show()
	_pickup_tween = create_tween().set_parallel(true)
	_pickup_tween.tween_property(pickup_label, "position:y", 486.0, 0.85)
	_pickup_tween.tween_property(pickup_label, "modulate:a", 0.0, 0.45).set_delay(0.4)


func show_game_over(metres: float) -> void:
	_game_over = true
	_clear_pickup_feedback()
	set_distance(metres)
	result_label.text = "%d m travelled" % int(metres)
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

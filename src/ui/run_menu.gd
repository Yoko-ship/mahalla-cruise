class_name RunMenu
extends Control
## Shared start/pause presentation. The parent routes the primary action.

signal primary_pressed
signal language_selected(locale: String)
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)

var is_pause: bool = false
var _best: int = 0
var _points: int = 0
var _metres: float = 0.0

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var subtitle: Label = $Center/Card/Margin/Content/Subtitle
@onready var car: TextureRect = $Center/Card/Margin/Content/Car
@onready var detail: Label = $Center/Card/Margin/Content/Detail
@onready var primary_button: Button = $Center/Card/Margin/Content/Primary
@onready var preferences: MenuPreferences = $Center/Card/Margin/Content/Preferences
@onready var instructions: Label = $Center/Card/Margin/Content/Instructions


func _ready() -> void:
	primary_button.pressed.connect(func() -> void: primary_pressed.emit())
	preferences.language_selected.connect(
		func(locale: String) -> void: language_selected.emit(locale)
	)
	preferences.sound_toggled.connect(func(enabled: bool) -> void: sound_toggled.emit(enabled))
	preferences.haptics_toggled.connect(func(enabled: bool) -> void: haptics_toggled.emit(enabled))


func show_start(best: int) -> void:
	is_pause = false
	_best = best
	refresh_text()
	show()
	primary_button.grab_focus()


func show_pause(points: int, metres: float) -> void:
	is_pause = true
	_points = points
	_metres = metres
	refresh_text()
	show()
	primary_button.grab_focus()


func refresh_text() -> void:
	title.text = tr("paused") if is_pause else "Mahalla\nCruise"
	title.add_theme_font_size_override("font_size", 34 if is_pause else 42)
	subtitle.text = tr("pause_message") if is_pause else tr("tagline")
	car.visible = not is_pause
	detail.text = (tr("run_summary") % [_points, int(_metres)] if is_pause else tr("best") % _best)
	primary_button.text = tr("resume") if is_pause else tr("play")
	instructions.text = tr("hint").replace("\\n", "\n")


func set_options(sound: bool, haptics: bool, unsaved: bool) -> void:
	preferences.set_options(sound, haptics, unsaved)


func close() -> void:
	primary_button.release_focus()
	hide()

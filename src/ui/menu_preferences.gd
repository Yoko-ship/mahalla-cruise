class_name MenuPreferences
extends VBoxContainer
## Menu controls emit choices upward; storage and audio belong to other features.

signal language_selected(locale: String)
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)

@onready var languages: HBoxContainer = $Languages
@onready var sound_button: Button = $Feedback/Sound
@onready var haptics_button: Button = $Feedback/Haptics
@onready var save_warning: Label = $SaveWarning


func _ready() -> void:
	for index in range(ProgressData.LANGUAGES.size()):
		var button := languages.get_child(index) as Button
		button.pressed.connect(_on_language_pressed.bind(ProgressData.LANGUAGES[index]))
	sound_button.toggled.connect(func(enabled: bool) -> void: sound_toggled.emit(enabled))
	haptics_button.toggled.connect(func(enabled: bool) -> void: haptics_toggled.emit(enabled))
	haptics_button.visible = OS.has_feature("android")


func set_options(sound: bool, haptics: bool, unsaved: bool) -> void:
	sound_button.set_pressed_no_signal(sound)
	haptics_button.set_pressed_no_signal(haptics)
	sound_button.text = tr("sound_on") if sound else tr("sound_off")
	haptics_button.text = tr("haptics_on") if haptics else tr("haptics_off")
	save_warning.visible = unsaved
	var locale := TranslationServer.get_locale().get_slice("_", 0)
	for index in range(ProgressData.LANGUAGES.size()):
		var button := languages.get_child(index) as Button
		button.set_pressed_no_signal(ProgressData.LANGUAGES[index] == locale)


func _on_language_pressed(locale: String) -> void:
	language_selected.emit(locale)

class_name PreferenceRules
extends RefCounted
## Saves menu options and applies them to audio, feedback, and the HUD.
## Main passes every node explicitly; nothing is looked up.


static func set_option(store: LocalProgressStore, option: String, enabled: bool) -> void:
	match option:
		"music":
			store.set_music_enabled(enabled)
		"sound":
			store.set_preferences(store.language, enabled, store.haptics_enabled)
		"haptics":
			store.set_preferences(store.language, store.sound_enabled, enabled)


static func apply(
	store: LocalProgressStore, feedback: PickupFeedback, audio: GameAudio, hud: CruiseHUD
) -> void:
	TranslationServer.set_locale(store.language)
	feedback.set_sound_enabled(store.sound_enabled)
	feedback.set_haptics_enabled(store.haptics_enabled)
	audio.set_options(store.sound_enabled, store.music_enabled)
	hud.refresh_text()
	hud.set_feedback_options(
		store.sound_enabled, store.haptics_enabled, store.has_unsaved_changes, store.music_enabled
	)

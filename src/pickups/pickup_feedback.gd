class_name PickupFeedback
extends Node
## Owns pickup audio and brief device pulses. Main supplies collection events.

@export var settings: PickupFeedbackSettings

var sound_enabled: bool = true
var haptics_enabled: bool = true
var _last_feedback_ms: int = -100000
var _focused: bool = true

@onready var som_sound: AudioStreamPlayer = $SomSound
@onready var dollar_sound: AudioStreamPlayer = $DollarSound


func _ready() -> void:
	assert(settings != null, "Pickup feedback requires settings")
	sound_enabled = settings.sound_enabled
	haptics_enabled = settings.haptics_enabled
	som_sound.volume_db = settings.volume_db
	dollar_sound.volume_db = settings.volume_db


func play_pickup(is_dollar: bool) -> void:
	if not _focused:
		return
	var now := Time.get_ticks_msec()
	if now - _last_feedback_ms < settings.minimum_interval_ms:
		return
	_last_feedback_ms = now
	if sound_enabled:
		var player := dollar_sound if is_dollar else som_sound
		player.play()
	if haptics_enabled and OS.has_feature("android"):
		var duration := settings.dollar_vibration_ms if is_dollar else settings.som_vibration_ms
		Input.vibrate_handheld(duration, settings.vibration_strength)


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	if not enabled:
		stop()


func set_haptics_enabled(enabled: bool) -> void:
	haptics_enabled = enabled


func stop() -> void:
	som_sound.stop()
	dollar_sound.stop()
	_last_feedback_ms = -100000


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true


func _exit_tree() -> void:
	stop()

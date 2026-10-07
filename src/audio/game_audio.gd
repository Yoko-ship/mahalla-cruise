class_name GameAudio
extends Node
## Background music and the horn. Main starts, pauses, and stops music with the run.

@export var settings: AudioSettings

var sound_enabled: bool = true
var music_enabled: bool = true
var _music_wanted: bool = false
var _focused: bool = true
var _last_horn_ms: int = -100000

@onready var music: AudioStreamPlayer = $Music
@onready var horn: AudioStreamPlayer = $Horn


func _ready() -> void:
	assert(settings != null, "Game audio requires settings")
	music.volume_db = settings.music_volume_db
	horn.volume_db = settings.horn_volume_db


func set_options(sound: bool, music_on: bool) -> void:
	sound_enabled = sound
	music_enabled = music_on
	if not sound:
		horn.stop()
	_update_music()


func play_horn() -> void:
	var now := Time.get_ticks_msec()
	if not sound_enabled or not _focused or now - _last_horn_ms < settings.horn_cooldown_ms:
		return
	_last_horn_ms = now
	horn.play()


## Music follows the drive: on while playing, paused in menus, restarted after a crash.
func set_music_playing(playing: bool, restart: bool = false) -> void:
	_music_wanted = playing
	if restart:
		music.stop()
	_update_music()


func _update_music() -> void:
	var audible := _music_wanted and music_enabled and _focused
	if audible and not music.playing:
		music.play()
	music.stream_paused = not audible


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		horn.stop()
		_update_music()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true
		_update_music()


func _exit_tree() -> void:
	music.stop()
	horn.stop()

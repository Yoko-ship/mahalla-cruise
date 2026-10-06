class_name LocalProgressStore
extends Node
## Local persistence only. Main coordinates scores; this node owns files and recovery.

const MAX_FILE_BYTES: int = 1048576

# Set before load_progress(). An empty path keeps test sessions entirely in memory.
@export var save_path: String = "user://progress.json"

var best_score: int = 0
var driving_hint_seen: bool = false
var language: String = "uz"
var sound_enabled: bool = true
var haptics_enabled: bool = true
var last_error: Error = OK
var has_unsaved_changes: bool = false
var _document: Dictionary = ProgressData.defaults()
var _write_blocked: bool = false


func load_progress() -> void:
	best_score = 0
	driving_hint_seen = false
	language = "uz"
	sound_enabled = true
	haptics_enabled = true
	last_error = OK
	has_unsaved_changes = false
	_write_blocked = false
	_document = ProgressData.defaults()
	if save_path.is_empty():
		return
	var document := _read_document(save_path)
	if _write_blocked:
		return
	if not ProgressData.is_supported(document):
		document = _read_document(save_path + ".bak")
	if ProgressData.is_supported(document):
		_document = document
		best_score = int(document.stats.best_score)
		driving_hint_seen = document.get("onboarding", {}).get("driving_hint_seen", false)
		var options := ProgressData.preferences(document)
		language = options.language
		sound_enabled = options.sound_enabled
		haptics_enabled = options.haptics_enabled


func set_preferences(locale: String, sound: bool, haptics: bool) -> void:
	if locale not in ProgressData.LANGUAGES:
		return
	var changed := language != locale or sound_enabled != sound or haptics_enabled != haptics
	if not changed and not has_unsaved_changes:
		return
	language = locale
	sound_enabled = sound
	haptics_enabled = haptics
	if not _document.get("preferences") is Dictionary:
		_document.preferences = {}
	_document.preferences.merge(
		{"language": locale, "sound_enabled": sound, "haptics_enabled": haptics}, true
	)
	last_error = _save()
	has_unsaved_changes = last_error != OK


func mark_driving_hint_seen() -> void:
	if driving_hint_seen:
		return
	driving_hint_seen = true
	if not _document.has("onboarding"):
		_document.onboarding = {}
	_document.onboarding.driving_hint_seen = true
	has_unsaved_changes = true
	last_error = _save()
	has_unsaved_changes = last_error != OK


func record_score(score: int) -> bool:
	# Return whether this run set a record; persistence status is reported separately.
	var improved := score > best_score and score <= ProgressData.MAX_SCORE
	if improved:
		best_score = score
		_document.stats.best_score = best_score
		has_unsaved_changes = true
	if has_unsaved_changes:
		last_error = _save()
		has_unsaved_changes = last_error != OK
	return improved


func _read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = FileAccess.get_open_error()
		_write_blocked = true
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		last_error = ERR_FILE_CORRUPT
		_write_blocked = true
		return {}
	var document := ProgressData.parse(file.get_as_text())
	file.close()
	if ProgressData.is_newer(document):
		last_error = ERR_UNAVAILABLE
		_write_blocked = true
	return document


func _save() -> Error:
	if _write_blocked:
		return last_error
	if save_path.is_empty():
		return OK
	# A closed temporary file replaces the primary only after a successful write.
	var error := _write_document(save_path + ".tmp", _document)
	if error != OK:
		return error
	# Preserve the last valid primary; a corrupt primary must not replace the backup.
	var previous := _read_document(save_path)
	if _write_blocked:
		return last_error
	if ProgressData.is_supported(previous):
		error = _write_document(save_path + ".bak.tmp", previous)
		if error == OK:
			error = _replace(save_path + ".bak.tmp", save_path + ".bak")
		if error != OK:
			return error
	return _replace(save_path + ".tmp", save_path)


func _write_document(path: String, document: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error


func _replace(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination)
	)

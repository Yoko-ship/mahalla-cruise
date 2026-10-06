extends SceneTree

var failures: int = 0
var checks: int = 0
var _directory: String
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_directory = "user://progress_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_absolute(_directory)
	_path = _directory.path_join("progress.json")
	_test_round_trip()
	_test_recovery()
	_test_invalid_data()
	_test_future_and_unknown_fields()
	_test_onboarding_extension()
	_test_write_failure()
	_clean_files()
	DirAccess.remove_absolute(_directory)
	if failures == 0:
		print(
			(
				"PASS: versioned local saves, recovery, forward safety, and write failures (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _new_store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _test_round_trip() -> void:
	var store := _new_store()
	_check(store.best_score == 0, "First launch starts at zero")
	_check(not FileAccess.file_exists(_path), "Loading never writes defaults over files")
	_check(not store.record_score(0), "A zero run is not a record")
	_check(store.record_score(125), "A higher score establishes a record")
	_check(store.last_error == OK and not store.has_unsaved_changes, "Successful save is reported")
	var first := FileAccess.get_file_as_string(_path)
	_check(not store.record_score(125), "A tie is not a new record")
	_check(not store.record_score(3), "Lower scores cannot reduce a record")
	_check(not store.record_score(-1), "Negative scores are ignored")
	_check(
		FileAccess.get_file_as_string(_path) == first, "Unchanged records do not rewrite the save"
	)
	store.free()
	store = _new_store()
	_check(store.best_score == 125, "A fresh storage instance loads the saved record")
	store.record_score(250)
	_check(store.best_score == 250, "Later records replace the primary")
	var backup := ProgressData.parse(FileAccess.get_file_as_string(_path + ".bak"))
	_check(backup.stats.best_score == 125, "Backup contains the previous valid record")
	_check(
		not FileAccess.file_exists(_path + ".tmp"), "Successful replacement consumes the temp file"
	)
	store.free()


func _test_recovery() -> void:
	_write(_path, "{interrupted")
	_write(_path + ".tmp", '{"version":1,"stats":{"best_score":999}}')
	var store := _new_store()
	_check(store.best_score == 125, "Corrupt primary recovers the previous committed record")
	_check(
		FileAccess.get_file_as_string(_path) == "{interrupted", "Loading does not erase bad data"
	)
	store.record_score(300)
	var backup := ProgressData.parse(FileAccess.get_file_as_string(_path + ".bak"))
	_check(backup.stats.best_score == 125, "Corrupt primary never replaces the good backup")
	store.free()
	store = _new_store()
	_check(store.best_score == 300, "Recovery allows a later record to persist normally")
	store.free()
	_clean_files()
	_write(_path, "broken")
	_write(_path + ".bak", "also broken")
	store = _new_store()
	_check(store.best_score == 0, "Two damaged files fall back to a playable zero record")
	_check(store.record_score(5) and store.last_error == OK, "New progress replaces damaged data")
	store.free()


func _test_invalid_data() -> void:
	var invalid: Array[String] = [
		"[]",
		"null",
		"{}",
		'{"version":1}',
		'{"version":true,"stats":{"best_score":10}}',
		'{"version":1,"stats":[]}',
		'{"version":1,"stats":{"best_score":"10"}}',
		'{"version":1,"stats":{"best_score":true}}',
		'{"version":1,"stats":{"best_score":-1}}',
		'{"version":1,"stats":{"best_score":1.5}}',
		'{"version":1,"stats":{"best_score":2147483648}}'
	]
	for text in invalid:
		_check(
			not ProgressData.is_supported(ProgressData.parse(text)), "Reject invalid save: " + text
		)
	_clean_files()
	_write(_path, '{"version":1,"stats":{"best_score":-50}}')
	var store := _new_store()
	_check(store.best_score == 0, "Invalid score data cannot reach gameplay")
	store.free()


func _test_future_and_unknown_fields() -> void:
	_clean_files()
	var future := '{"version":2,"stats":{"best_score":500},"future_data":true}'
	_write(_path, future)
	var store := _new_store()
	_check(
		store.best_score == 0 and store.last_error == ERR_UNAVAILABLE, "Newer schema stays unread"
	)
	store.record_score(999)
	_check(store.has_unsaved_changes, "Unsupported version reports session-only progress")
	_check(
		FileAccess.get_file_as_string(_path) == future, "An older app cannot overwrite a newer save"
	)
	store.free()
	_write(_path, '{"version":1,"stats":{"best_score":5,"runs":7},"settings":{"sound":false}}')
	store = _new_store()
	store.record_score(10)
	var saved := ProgressData.parse(FileAccess.get_file_as_string(_path))
	_check(
		saved.stats.runs == 7 and saved.settings.sound == false, "Unknown fields survive updates"
	)
	_check(saved.version == 1 and saved.stats.best_score == 10, "Known fields update within schema")
	store.free()


func _test_onboarding_extension() -> void:
	_clean_files()
	_write(_path, '{"version":1,"stats":{"best_score":75},"settings":{"sound":false}}')
	var store := _new_store()
	_check(
		store.best_score == 75 and not store.driving_hint_seen,
		"Older v1 saves load without a hint flag"
	)
	store.mark_driving_hint_seen()
	_check(
		store.last_error == OK and store.driving_hint_seen,
		"Onboarding saves through the same store"
	)
	var saved := FileAccess.get_file_as_string(_path)
	store.mark_driving_hint_seen()
	_check(
		FileAccess.get_file_as_string(_path) == saved,
		"Repeated onboarding does not rewrite the file"
	)
	store.free()
	store = _new_store()
	_check(
		store.best_score == 75 and store.driving_hint_seen,
		"Best and hint survive reopening together"
	)
	var document := ProgressData.parse(saved)
	_check(document.settings.sound == false, "Adding onboarding preserves other save fields")
	document.onboarding.driving_hint_seen = "yes"
	_check(not ProgressData.is_supported(document), "Malformed onboarding flags are rejected")
	store.free()


func _test_write_failure() -> void:
	var store := LocalProgressStore.new()
	store.save_path = _directory.path_join("missing/progress.json")
	store.load_progress()
	_check(store.record_score(42), "A write failure still keeps the record for this session")
	_check(store.best_score == 42 and store.has_unsaved_changes, "Unsaved progress stays in memory")
	_check(store.last_error != OK, "Storage failure is observable by the caller")
	DirAccess.make_dir_absolute(_directory.path_join("missing"))
	_check(not store.record_score(10), "Retrying a pending save does not invent a record")
	_check(
		not store.has_unsaved_changes and store.last_error == OK, "Later runs retry pending saves"
	)
	store.load_progress()
	_check(store.best_score == 42, "Retry persists the highest score, not the lower retry score")
	DirAccess.remove_absolute(store.save_path)
	DirAccess.remove_absolute(_directory.path_join("missing"))
	store.free()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean_files() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

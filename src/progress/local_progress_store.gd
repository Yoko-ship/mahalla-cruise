class_name LocalProgressStore
extends Node
## Local persistence only. Main coordinates scores; this node owns files and recovery.

# Set before load_progress(). An empty path keeps test sessions entirely in memory.
@export var save_path: String = "user://progress.json"

var best_score: int = 0
var driving_hint_seen: bool = false
var language: String = "uz"
var sound_enabled: bool = true
var haptics_enabled: bool = true
var music_enabled: bool = true
var wallet: int = 0
var owned_cars: Array[String] = [ProgressData.DEFAULT_CAR]
var selected_car: String = ProgressData.DEFAULT_CAR
var owned_paints: Array[String] = []
## Chosen paint per car id; GarageRules falls back to the car's factory paint.
var paints: Dictionary = {}
## Upgrade levels per car id: {car_id: {upgrade_id: level}}.
var upgrades: Dictionary = {}
## Saved daily task state; DailyTasks validates it against today's date and its catalogue.
var daily: Dictionary = {}
## Saved lifetime totals and unlocked ids; Achievements validates them.
var achievements: Dictionary = {}
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
	music_enabled = true
	_apply_garage(ProgressData.garage({}))
	daily = {}
	achievements = {}
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
		music_enabled = options.music_enabled
		_apply_garage(ProgressData.garage(document))
		daily = _section(document, "daily")
		achievements = _section(document, "achievements")


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


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled and not has_unsaved_changes:
		return
	music_enabled = enabled
	if not _document.get("preferences") is Dictionary:
		_document.preferences = {}
	_document.preferences.music_enabled = enabled
	_commit()


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


func complete_run(score: int) -> bool:
	# A finished run pays into the wallet and checks the record with a single write.
	if score > 0 and score <= ProgressData.MAX_SCORE:
		wallet = mini(wallet + score, ProgressData.MAX_SCORE)
		_store_garage()
	return record_score(score)


# Staged sections are saved by the next write (normally complete_run), so a finished
# run stays one write. Rewards go into the wallet in the same write.
func stage_daily(state: Dictionary, rewards: Array[int]) -> void:
	daily = state.duplicate(true)
	_stage("daily", daily, rewards)


func stage_achievements(state: Dictionary, rewards: Array[int]) -> void:
	achievements = state.duplicate(true)
	_stage("achievements", achievements, rewards)


func _stage(key: String, state: Dictionary, rewards: Array[int]) -> void:
	if not _document.get(key) is Dictionary:
		_document[key] = {}
	_document[key].merge(state.duplicate(true), true)
	for reward in rewards:
		wallet = mini(wallet + maxi(0, reward), ProgressData.MAX_SCORE)
	_store_garage()


static func _section(document: Dictionary, key: String) -> Dictionary:
	var saved: Variant = document.get(key, {})
	return saved.duplicate(true) if saved is Dictionary else {}


func buy_car(id: String, price: int) -> bool:
	# Buying also selects the car, so the purchase is one write.
	if id.is_empty() or id in owned_cars or price < 0 or price > wallet:
		return false
	wallet -= price
	owned_cars.append(id)
	selected_car = id
	_store_garage()
	_commit()
	return true


func buy_paint(car_id: String, paint_id: String, price: int) -> bool:
	# Buying also applies the paint to the current car in the same write.
	if paint_id.is_empty() or paint_id in owned_paints or price < 0 or price > wallet:
		return false
	wallet -= price
	owned_paints.append(paint_id)
	paints[car_id] = paint_id
	_store_garage()
	_commit()
	return true


func buy_upgrade(car_id: String, upgrade_id: String, price: int) -> bool:
	# Raises one level; UpgradeRules checks the level limit before buying.
	if car_id.is_empty() or upgrade_id.is_empty() or price < 0 or price > wallet:
		return false
	wallet -= price
	var levels: Dictionary = upgrades.get(car_id, {})
	levels[upgrade_id] = int(levels.get(upgrade_id, 0)) + 1
	upgrades[car_id] = levels
	_store_garage()
	_commit()
	return true


func select_paint(car_id: String, paint_id: String) -> void:
	if paints.get(car_id) == paint_id and not has_unsaved_changes:
		return
	paints[car_id] = paint_id
	_store_garage()
	_commit()


func select_car(id: String) -> void:
	if id not in owned_cars or (id == selected_car and not has_unsaved_changes):
		return
	selected_car = id
	_store_garage()
	_commit()


func _apply_garage(values: Dictionary) -> void:
	wallet = values.wallet
	owned_cars.assign(values.owned)
	selected_car = values.selected
	owned_paints.assign(values.owned_paints)
	paints = values.paints.duplicate()
	upgrades = values.upgrades.duplicate(true)


func _store_garage() -> void:
	if not _document.get("garage") is Dictionary:
		_document.garage = {}
	(
		_document
		. garage
		. merge(
			{
				"wallet": wallet,
				"owned": owned_cars.duplicate(),
				"selected": selected_car,
				"owned_paints": owned_paints.duplicate(),
				"paints": paints.duplicate(),
				"upgrades": upgrades.duplicate(true),
			},
			true
		)
	)
	has_unsaved_changes = true


func _commit() -> void:
	last_error = _save()
	has_unsaved_changes = last_error != OK


func _read_document(path: String) -> Dictionary:
	var result := ProgressFile.read(path)
	if result.blocked:
		last_error = result.error
		_write_blocked = true
	return result.document


func _save() -> Error:
	if _write_blocked:
		return last_error
	if save_path.is_empty():
		return OK
	# A closed temporary file replaces the primary only after a successful write.
	var error := ProgressFile.write(save_path + ".tmp", _document)
	if error != OK:
		return error
	# Preserve the last valid primary; a corrupt primary must not replace the backup.
	var previous := _read_document(save_path)
	if _write_blocked:
		return last_error
	if ProgressData.is_supported(previous):
		error = ProgressFile.write(save_path + ".bak.tmp", previous)
		if error == OK:
			error = ProgressFile.replace(save_path + ".bak.tmp", save_path + ".bak")
		if error != OK:
			return error
	return ProgressFile.replace(save_path + ".tmp", save_path)

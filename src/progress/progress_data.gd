class_name ProgressData
extends RefCounted
## Versioned save document. Extend this boundary when adding fields or migrations.

const VERSION: int = 1
const MAX_SCORE: int = 2147483647
const LANGUAGES: Array[String] = ["uz", "ru", "en"]
const DEFAULT_CAR: String = "damas"
const MAX_UPGRADE_LEVEL: int = 10
const DEFAULT_PLATE: String = "01A482DM"
const DEFAULT_ROUTE: String = "tashkent"


static func defaults() -> Dictionary:
	return {
		"version": VERSION, "stats": {"best_score": 0}, "onboarding": {"driving_hint_seen": false}
	}


static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data


static func is_supported(document: Dictionary) -> bool:
	if not is_integer(document.get("version")) or document.version != VERSION:
		return false
	var stats: Variant = document.get("stats")
	if not stats is Dictionary:
		return false
	var best: Variant = stats.get("best_score")
	if not is_integer(best) or best < 0 or best > MAX_SCORE:
		return false
	# Optional v1 extension: saves from before onboarding remain compatible.
	var onboarding: Variant = document.get("onboarding", {})
	return onboarding is Dictionary and onboarding.get("driving_hint_seen", false) is bool


static func is_newer(document: Dictionary) -> bool:
	var version: Variant = document.get("version")
	return is_integer(version) and version > VERSION


static func preferences(document: Dictionary) -> Dictionary:
	# Optional settings must never make an otherwise valid record unreadable.
	var result := {
		"language": "uz", "sound_enabled": true, "haptics_enabled": true, "music_enabled": true
	}
	var saved: Variant = document.get("preferences", {})
	if not saved is Dictionary:
		return result
	if saved.get("language") is String and saved.language in LANGUAGES:
		result.language = saved.language
	for key: String in ["sound_enabled", "haptics_enabled", "music_enabled"]:
		if saved.get(key) is bool:
			result[key] = saved[key]
	return result


static func garage(document: Dictionary) -> Dictionary:
	# Optional v1 extension: invalid fields fall back individually, keeping the record.
	var result := {
		"wallet": 0,
		"owned": [DEFAULT_CAR],
		"selected": DEFAULT_CAR,
		"owned_paints": [],
		"paints": {},
		"upgrades": {},
		"plates": [DEFAULT_PLATE],
		"plate": DEFAULT_PLATE,
		"conditions": {},
		"routes": [DEFAULT_ROUTE],
		"route": DEFAULT_ROUTE,
	}
	var saved: Variant = document.get("garage", {})
	if not saved is Dictionary:
		return result
	var wallet: Variant = saved.get("wallet")
	if is_integer(wallet) and wallet >= 0 and wallet <= MAX_SCORE:
		result.wallet = int(wallet)
	if saved.get("owned") is Array:
		for id: Variant in saved.owned:
			if id is String and not id.is_empty() and id not in result.owned:
				result.owned.append(id)
	if saved.get("selected") is String and saved.selected in result.owned:
		result.selected = saved.selected
	if saved.get("owned_paints") is Array:
		for id: Variant in saved.owned_paints:
			if id is String and not id.is_empty() and id not in result.owned_paints:
				result.owned_paints.append(id)
	if saved.get("paints") is Dictionary:
		for car: Variant in saved.paints:
			if car is String and saved.paints[car] is String:
				result.paints[car] = saved.paints[car]
	if saved.get("upgrades") is Dictionary:
		for car: Variant in saved.upgrades:
			if car is String and saved.upgrades[car] is Dictionary:
				result.upgrades[car] = _levels(saved.upgrades[car])
	_collection(saved, "plates", "plate", result, is_plate)
	_collection(
		saved, "routes", "route", result, func(id: String) -> bool: return not id.is_empty()
	)
	if saved.get("conditions") is Dictionary:
		for car: Variant in saved.conditions:
			var percent: Variant = saved.conditions[car]
			if car is String and is_integer(percent) and percent >= 1 and percent < 100:
				result.conditions[car] = int(percent)
	return result


## Uzbek private plate code: region digits, a letter, three digits, two letters.
static func is_plate(code: String) -> bool:
	if code.length() != 8 or code.substr(3, 3) == "000":
		return false
	for index in range(8):
		var digit := index < 2 or (index >= 3 and index <= 5)
		var letter := code[index] >= "A" and code[index] <= "Z"
		if (code[index].is_valid_int() if digit else letter) == false:
			return false
	return true


## Owned ids (merged into the defaults) and a selection that must be owned.
static func _collection(
	saved: Dictionary, list_key: String, pick_key: String, result: Dictionary, valid: Callable
) -> void:
	if saved.get(list_key) is Array:
		for id: Variant in saved[list_key]:
			if id is String and valid.call(id) and id not in result[list_key]:
				result[list_key].append(id)
	if saved.get(pick_key) is String and saved[pick_key] in result[list_key]:
		result[pick_key] = saved[pick_key]


static func _levels(saved: Dictionary) -> Dictionary:
	var levels := {}
	for id: Variant in saved:
		var level: Variant = saved[id]
		if id is String and is_integer(level) and level > 0 and level <= MAX_UPGRADE_LEVEL:
			levels[id] = int(level)
	return levels


static func is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)

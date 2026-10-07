class_name ProgressData
extends RefCounted
## Versioned save document. Extend this boundary when adding fields or migrations.

const VERSION: int = 1
const MAX_SCORE: int = 2147483647
const LANGUAGES: Array[String] = ["uz", "ru", "en"]
const DEFAULT_CAR: String = "damas"


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
	var result := {"language": "uz", "sound_enabled": true, "haptics_enabled": true}
	var saved: Variant = document.get("preferences", {})
	if not saved is Dictionary:
		return result
	if saved.get("language") is String and saved.language in LANGUAGES:
		result.language = saved.language
	for key: String in ["sound_enabled", "haptics_enabled"]:
		if saved.get(key) is bool:
			result[key] = saved[key]
	return result


static func garage(document: Dictionary) -> Dictionary:
	# Optional v1 extension: invalid fields fall back individually, keeping the record.
	var result := {"wallet": 0, "owned": [DEFAULT_CAR], "selected": DEFAULT_CAR}
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
	return result


static func is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)

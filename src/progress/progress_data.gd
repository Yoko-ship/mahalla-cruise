class_name ProgressData
extends RefCounted
## Versioned save document. Extend this boundary when adding fields or migrations.

const VERSION: int = 1
const MAX_SCORE: int = 2147483647


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


static func is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)

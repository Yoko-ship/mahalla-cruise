class_name Achievements
extends Node
## Lifetime totals and unlocked goals. Main reports finished runs; the progress store saves
## the state. Each goal pays its reward once.

## Run summary keys added up over every drive.
const TOTALS: Array[String] = ["metres", "notes", "close_calls", "runs", "refuels"]
## Saved best single-run values and the run summary key each comes from.
const BESTS: Dictionary = {"best_metres": "metres", "best_score": "score"}

@export var catalogue: AchievementCatalogue

## {"stats": {stat key: value}, "done": [ids]}.
var state: Dictionary = {"stats": {}, "done": []}


func load_state(saved: Dictionary) -> void:
	assert(catalogue != null, "Achievements require a catalogue")
	state = {"stats": {}, "done": []}
	var stats: Variant = saved.get("stats")
	if stats is Dictionary:
		for key: Variant in stats:
			var value: Variant = stats[key]
			if key is String and ProgressData.is_integer(value) and value >= 0:
				state.stats[key] = mini(int(value), ProgressData.MAX_SCORE)
	var done: Variant = saved.get("done")
	if done is Array:
		for id: Variant in done:
			if id is String and catalogue.find(id) != null and id not in state.done:
				state.done.append(id)


## Adds a finished run (DailyTasks.summary) and returns rewards of newly unlocked goals.
func record_run(run: Dictionary) -> Array[int]:
	for key in TOTALS:
		var total := int(state.stats.get(key, 0)) + maxi(0, int(run.get(key, 0)))
		state.stats[key] = mini(total, ProgressData.MAX_SCORE)
	for key: String in BESTS:
		state.stats[key] = maxi(int(state.stats.get(key, 0)), int(run.get(BESTS[key], 0)))
	var rewards: Array[int] = []
	for achievement in catalogue.achievements:
		if achievement.id not in state.done and progress(achievement) >= achievement.target:
			state.done.append(achievement.id)
			rewards.append(achievement.reward)
	return rewards


func progress(achievement: AchievementDefinition) -> int:
	return int(state.stats.get(achievement.stat_key(), 0))


## One row per kind: its first locked goal, or its last goal once all are unlocked.
func entries() -> Array[Dictionary]:
	var shown := {}
	for achievement in catalogue.achievements:
		var current: AchievementDefinition = shown.get(achievement.kind)
		if current == null or current.id in state.done:
			shown[achievement.kind] = achievement
	var result: Array[Dictionary] = []
	for kind: int in AchievementDefinition.Kind.values():
		if not shown.has(kind):
			continue
		var achievement: AchievementDefinition = shown[kind]
		var scale := achievement.display_scale()
		var target := achievement.target / scale
		var entry := {
			"text_key": achievement.text_key(),
			"target": target,
			"progress": mini(progress(achievement) / scale, target),
			"reward": achievement.reward,
			"done": achievement.id in state.done,
		}
		result.append(entry)
	return result

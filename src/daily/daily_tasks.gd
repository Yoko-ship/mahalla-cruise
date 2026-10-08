class_name DailyTasks
extends Node
## Today's tasks and progress. Main reports finished runs; the progress store saves the state.

@export var catalogue: DailyCatalogue
## Day N of a streak pays N × this on the first finished drive, up to the cap.
@export_range(0, 1000) var streak_step_reward: int = 20
@export_range(1, 30) var streak_cap_days: int = 7

## {"day": "YYYY-MM-DD", "tasks": [ids], "progress": {id: value}, "done": [ids],
##  "streak": days in a row, "streak_paid": bool}. Saves without the streak keys
## (older versions) show no streak row for that day.
var state: Dictionary = {}


## The run summary that record_run() and Achievements.record_run() expect.
static func summary(
	notes: int, close_calls: int, metres: float, score: int, refuels: int = 0
) -> Dictionary:
	return {
		"notes": notes,
		"close_calls": close_calls,
		"metres": int(metres),
		"score": score,
		"runs": 1,
		"refuels": refuels,
	}


static func today() -> String:
	return Time.get_date_string_from_system()


func load_state(saved: Dictionary, day: String = "") -> void:
	assert(catalogue != null, "Daily tasks require a catalogue")
	if day.is_empty():
		day = today()
	if _is_valid(saved, day):
		state = saved.duplicate(true)
		return
	state = _new_state(day)
	# Driving yesterday continues the streak; any gap starts again at day one.
	var continued: bool = (
		saved.get("day") == _previous_day(day) and saved.get("streak_paid") == true
	)
	var previous: Variant = saved.get("streak", 0)
	var days := int(previous) + 1 if continued and ProgressData.is_integer(previous) else 1
	state.streak = clampi(days, 1, 100000)
	state.streak_paid = false


## Returns the rewards of tasks this run completed. A new day starts new tasks first.
func record_run(run: Dictionary, day: String = "") -> Array[int]:
	load_state(state, day)
	var rewards: Array[int] = []
	for id: String in state.tasks:
		var task := catalogue.find(id)
		var value := int(run.get(task.stat(), 0))
		var current := int(state.progress.get(id, 0))
		current = current + value if task.is_cumulative() else maxi(current, value)
		state.progress[id] = mini(current, task.target)
		if current >= task.target and id not in state.done:
			state.done.append(id)
			rewards.append(task.reward)
	if state.get("streak_paid") == false:
		state.streak_paid = true
		rewards.append(streak_reward())
	return rewards


func streak_reward() -> int:
	return mini(int(state.get("streak", 1)), streak_cap_days) * streak_step_reward


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in state.get("tasks", []):
		var task := catalogue.find(id)
		(
			result
			. append(
				{
					"text_key": task.text_key(),
					"target": task.target,
					"progress": mini(int(state.progress.get(id, 0)), task.target),
					"reward": task.reward,
					"done": id in state.done,
				}
			)
		)
	if state.has("streak_paid"):
		var streak_entry := {
			"text_key": "task_streak",
			"target": int(state.get("streak", 1)),
			"progress": int(state.streak_paid),
			"reward": streak_reward(),
			"done": state.streak_paid,
			"counter": false,
		}
		result.append(streak_entry)
	return result


static func _previous_day(day: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)


func _new_state(day: String) -> Dictionary:
	# The date seeds the draw, so the same tasks return after a relaunch on the same day.
	var random := RandomNumberGenerator.new()
	random.seed = ("mahalla-daily:" + day).hash()
	var kinds: Array = DailyTaskDefinition.Kind.values()
	for index in range(kinds.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var swap: Variant = kinds[index]
		kinds[index] = kinds[other]
		kinds[other] = swap
	var ids: Array[String] = []
	for kind: DailyTaskDefinition.Kind in kinds:
		var options := catalogue.of_kind(kind)
		if options.is_empty() or ids.size() >= catalogue.tasks_per_day:
			continue
		ids.append(options[random.randi_range(0, options.size() - 1)].id)
	return {"day": day, "tasks": ids, "progress": {}, "done": []}


func _is_valid(saved: Dictionary, day: String) -> bool:
	if saved.get("day") != day or not saved.get("tasks") is Array:
		return false
	if not saved.get("progress") is Dictionary or not saved.get("done") is Array:
		return false
	if saved.tasks.size() != catalogue.tasks_per_day:
		return false
	for id: Variant in saved.tasks:
		if not id is String or catalogue.find(id) == null:
			return false
	for value: Variant in saved.progress.values():
		if not ProgressData.is_integer(value) or value < 0:
			return false
	return true

class_name DailyTasks
extends Node
## Today's tasks and progress. Main reports finished runs; the progress store saves the state.

@export var catalogue: DailyCatalogue

## {"day": "YYYY-MM-DD", "tasks": [ids], "progress": {id: value}, "done": [ids]}
var state: Dictionary = {}


static func today() -> String:
	return Time.get_date_string_from_system()


func load_state(saved: Dictionary, day: String = "") -> void:
	assert(catalogue != null, "Daily tasks require a catalogue")
	if day.is_empty():
		day = today()
	state = saved.duplicate(true) if _is_valid(saved, day) else _new_state(day)


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
	return rewards


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
	return result


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

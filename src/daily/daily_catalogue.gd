class_name DailyCatalogue
extends Resource
## Pool of daily tasks. Each day draws tasks of different kinds from it.

@export var tasks: Array[DailyTaskDefinition] = []
@export_range(1, 5) var tasks_per_day: int = 3


func find(id: String) -> DailyTaskDefinition:
	for task in tasks:
		if task.id == id:
			return task
	return null


func of_kind(kind: DailyTaskDefinition.Kind) -> Array[DailyTaskDefinition]:
	var result: Array[DailyTaskDefinition] = []
	for task in tasks:
		if task.kind == kind:
			result.append(task)
	return result

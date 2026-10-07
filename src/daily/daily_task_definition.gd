class_name DailyTaskDefinition
extends Resource
## One possible daily task. Progress lives in the saved daily state, never in this resource.

enum Kind { NOTES, CLOSE_CALLS, DISTANCE, SCORE, RUNS }

## Run summary keys supplied by main, in Kind order.
const STATS: Array[String] = ["notes", "close_calls", "metres", "score", "runs"]
const TEXT_KEYS: Array[String] = [
	"task_notes", "task_close_calls", "task_distance", "task_score", "task_runs"
]

@export var id: String = ""
@export var kind: Kind = Kind.NOTES
@export_range(1, 100000) var target: int = 10
@export_range(0, 100000) var reward: int = 50


func stat() -> String:
	return STATS[kind]


## Notes, close calls, and drives add up over the day; distance and score need one run.
func is_cumulative() -> bool:
	return kind in [Kind.NOTES, Kind.CLOSE_CALLS, Kind.RUNS]


func text_key() -> String:
	return TEXT_KEYS[kind]

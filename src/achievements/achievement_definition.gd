class_name AchievementDefinition
extends Resource
## One lifetime goal with a one-time reward. Totals add up over every drive; "run" goals
## need a single drive. Progress lives in the saved state, never in this resource.

enum Kind { DISTANCE, NOTES, CLOSE_CALLS, RUNS, REFUELS, RUN_DISTANCE, RUN_SCORE }

## Saved stat per kind, in Kind order.
const STAT_KEYS: Array[String] = [
	"metres", "notes", "close_calls", "runs", "refuels", "best_metres", "best_score"
]
const TEXT_KEYS: Array[String] = [
	"ach_distance",
	"ach_notes",
	"ach_close_calls",
	"ach_runs",
	"ach_refuels",
	"ach_run_distance",
	"ach_run_score",
]

@export var id: String = ""
@export var kind: Kind = Kind.DISTANCE
## Lifetime distance targets are metres, shown in kilometres.
@export_range(1, 100000000) var target: int = 1000
@export_range(0, 100000) var reward: int = 100


func stat_key() -> String:
	return STAT_KEYS[kind]


func text_key() -> String:
	return TEXT_KEYS[kind]


func display_scale() -> int:
	return 1000 if kind == Kind.DISTANCE else 1

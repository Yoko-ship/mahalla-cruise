class_name RunRecords
extends RefCounted
## Books a finished drive: daily tasks, achievements, wallet, and record in one write.


## Returns the rewards of newly finished daily tasks ("tasks") and achievements
## ("unlocked"), and whether the score is a new best ("new_best").
static func finish(
	run: Dictionary, daily: DailyTasks, achievements: Achievements, store: LocalProgressStore
) -> Dictionary:
	var tasks := daily.record_run(run)
	var unlocked := achievements.record_run(run)
	store.stage_daily(daily.state, tasks)
	store.stage_achievements(achievements.state, unlocked)
	var new_best := store.complete_run(int(run.score))
	return {"tasks": tasks, "unlocked": unlocked, "new_best": new_best}

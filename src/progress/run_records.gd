class_name RunRecords
extends RefCounted
## Books a finished drive: daily tasks, achievements, mahalla rivals passed, wallet, and
## record in one write.


## Returns the rewards of newly finished daily tasks ("tasks") and achievements
## ("unlocked"), the rivals passed ("rivals": {name, reward}), the next rival ahead
## ("next_rival": {name, score}, empty at the top), and whether the score is a new best.
static func finish(
	run: Dictionary,
	daily: DailyTasks,
	achievements: Achievements,
	store: LocalProgressStore,
	rivals: RivalLadder
) -> Dictionary:
	var tasks := daily.record_run(run)
	var unlocked := achievements.record_run(run)
	store.stage_daily(daily.state, tasks)
	store.stage_achievements(achievements.state, unlocked)
	var passed: Array[Dictionary] = []
	var rewards: Array[int] = []
	for index in rivals.newly_passed(store.best_score, int(run.score)):
		passed.append({"name": rivals.names[index], "reward": rivals.rewards[index]})
		rewards.append(rivals.rewards[index])
	store.stage_rewards(rewards)
	var new_best := store.complete_run(int(run.score))
	var next := rivals.next_index(store.best_score)
	var ahead := {} if next < 0 else {"name": rivals.names[next], "score": rivals.scores[next]}
	return {
		"tasks": tasks,
		"unlocked": unlocked,
		"rivals": passed,
		"next_rival": ahead,
		"new_best": new_best,
	}

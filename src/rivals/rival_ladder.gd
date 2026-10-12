class_name RivalLadder
extends Resource
## Mahalla reytingi: neighbourhood drivers with fixed best scores, easiest first. A best score
## above a driver's passes them and pays their reward once. Passing is worked out from the
## saved best score, so the save needs no extra field.

## How many drivers still ahead, and already passed, the tasks screen shows around the player.
const SHOWN_AHEAD: int = 3
const SHOWN_BEHIND: int = 2

@export var names: Array[String] = []
@export var scores: Array[int] = []
@export var rewards: Array[int] = []


## Indexes of the drivers that new_best passes and old_best did not.
func newly_passed(old_best: int, new_best: int) -> Array[int]:
	var passed: Array[int] = []
	for index in range(scores.size()):
		if old_best <= scores[index] and new_best > scores[index]:
			passed.append(index)
	return passed


## The player's place in the mahalla (1 is the top) with this best score.
func rank(best: int) -> int:
	return 1 + scores.filter(func(value: int) -> bool: return value >= best).size()


## The easiest driver still ahead, or -1 once everyone is passed.
func next_index(best: int) -> int:
	for index in range(scores.size()):
		if scores[index] >= best:
			return index
	return -1


## Rows for the tasks screen, top place first: the nearest drivers ahead, the player (empty
## name), and the drivers just passed. Each row has place, name, progress, target, reward, done.
func entries(best: int) -> Array[Dictionary]:
	var ahead := next_index(best)
	if ahead < 0:
		ahead = scores.size()
	var rows: Array[Dictionary] = []
	var behind := SHOWN_BEHIND + maxi(0, SHOWN_AHEAD - (scores.size() - ahead))
	var first := mini(scores.size() - 1, ahead + SHOWN_AHEAD - 1)
	for index in range(first, maxi(-1, ahead - behind - 1), -1):
		if index == ahead - 1:
			rows.append(_player_row(best))
		var passed := best > scores[index]
		(
			rows
			. append(
				{
					"place": scores.size() - index + int(passed),
					"name": names[index],
					"progress": mini(best, scores[index]),
					"target": scores[index],
					"reward": rewards[index],
					"done": passed,
				}
			)
		)
	if ahead == 0:
		rows.append(_player_row(best))
	return rows


func _player_row(best: int) -> Dictionary:
	return {
		"place": rank(best),
		"name": "",
		"progress": best,
		"target": maxi(1, best),
		"reward": 0,
		"done": false,
		"counter": false,
	}

class_name AchievementCatalogue
extends Resource
## Every lifetime goal. Within a kind, list goals from the smallest target up.

@export var achievements: Array[AchievementDefinition] = []


func find(id: String) -> AchievementDefinition:
	for achievement in achievements:
		if achievement.id == id:
			return achievement
	return null

class_name UpgradeDefinition
extends Resource
## One upgrade track, bought level by level for each car. Read-only during play.

## "handling" (steering), "tank" (fuel), or "suspension" (hazard penalties).
@export var id: String = ""
## Price of each level in order; the number of prices is the level limit.
@export var prices: Array[int] = [200, 450, 900]
## Change per level as a share: added to the base value, or removed when `reduces` is set.
@export_range(0.0, 1.0) var step: float = 0.1
@export var reduces: bool = false


func max_level() -> int:
	return mini(prices.size(), ProgressData.MAX_UPGRADE_LEVEL)


func price_for(level: int) -> int:
	return prices[level] if level >= 0 and level < max_level() else 0


func multiplier(level: int) -> float:
	var change := step * clampi(level, 0, max_level())
	return maxf(0.0, 1.0 - change) if reduces else 1.0 + change

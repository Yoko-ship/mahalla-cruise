class_name PlateSettings
extends Resource
## Number plate prices by rarity tier (common, nice, special, legendary) and the daily
## auction. Taxi passengers tip one extra fare note per tier.

@export var tier_prices: Array[int] = [150, 600, 2000, 6000]
## Chance that the auction's top plate is legendary instead of special.
@export_range(0.0, 1.0) var legendary_chance: float = 0.3
## Letters used on plates.
@export var letters: String = "ABDEFHKLMNOSTUXYZ"


func price_for(tier: int) -> int:
	return tier_prices[clampi(tier, 0, tier_prices.size() - 1)]

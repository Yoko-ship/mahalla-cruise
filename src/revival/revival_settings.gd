class_name RevivalSettings
extends Resource
## Second chance: once per drive, after a crash or an empty tank far enough along, the player
## may pay from the wallet to drive on with a little methane and a short grace.

## The price is this base plus price_share of the drive's points so far, so a long drive
## costs more to continue (a balance playtest found a flat 150 taken in most drives).
@export_range(0, 100000) var price: int = 150
@export_range(0.0, 2.0) var price_share: float = 0.25
## Drives that end sooner go straight to the results.
@export_range(0.0, 10000.0) var min_metres: float = 300.0
@export_range(1.0, 30.0) var decide_seconds: float = 7.0
## An empty tank is topped up to this share.
@export_range(0.05, 1.0) var refuel_share: float = 0.35
## Further contact is absorbed for this much travel.
@export_range(0.0, 500.0) var grace_metres: float = 45.0


func price_for(score: int) -> int:
	return price + roundi(maxi(0, score) * price_share)


func can_offer(already_revived: bool, metres: float, wallet: int, score: int = 0) -> bool:
	return not already_revived and metres >= min_metres and wallet >= price_for(score)

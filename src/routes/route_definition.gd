class_name RouteDefinition
extends Resource
## One city route: name, unlock price, plate region, points bonus, and look. Read-only.

@export var id: String = ""
## Text key of the route name.
@export var name_key: String = ""
@export_range(0, 1000000) var price: int = 0
## Region code on number plates offered while this route is chosen.
@export var region_code: String = "01"
## Multiplies money, close-call, taxi, and police points on this route.
@export_range(1.0, 3.0) var points_scale: float = 1.0
## Tints the street artwork until the city has its own painted street.
@export var tint := Color.WHITE
## Sidewalk landmarks drawn in code: "", "registan", "kalyan", or "itchan_kala".
@export var landmarks: String = ""


## The bonus shown to players, e.g. 15 for +15% points.
func bonus_percent() -> int:
	return roundi((points_scale - 1.0) * 100.0)

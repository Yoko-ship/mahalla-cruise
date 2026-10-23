class_name StreetArt
extends Resource
## A route's connected background and the source coordinates of its two road edges.

@export var name_key: String = ""
@export var texture: Texture2D
@export var source_curbs := Vector2(270, 674)
## Zero uses the full texture height; legacy mahalla art crops its repeated garden.
@export var source_height: float = 0.0
@export_range(100.0, 5000.0) var repeat_distance: float = 720.0
@export var bakery_sign: bool = false

class_name PoliceSettings
extends Resource
## GAI (YHXB) posts on the left sidewalk. Some officers wave drivers over: stopping slowly
## in the bay earns a reward, driving past costs a fine. Others just watch.

@export_range(0.0, 20000.0) var first_metres: float = 600.0
@export_range(50.0, 20000.0) var spawn_metres_min: float = 600.0
@export_range(50.0, 20000.0) var spawn_metres_max: float = 1000.0
@export_range(0.0, 1.0) var wave_chance: float = 0.6
## In the bay at or below this speedometer speed counts as stopping.
@export_range(5, 200) var stop_kmh: int = 40
@export_range(0, 1000) var reward_points: int = 20
@export_range(0, 1000) var fine_points: int = 30
## The car's left edge must come this close to the curb while level with the post.
@export_range(0.0, 60.0) var stop_distance: float = 18.0
@export_range(20.0, 300.0) var zone_height: float = 90.0
@export var spawn_y: float = -90.0
@export var despawn_y: float = 900.0

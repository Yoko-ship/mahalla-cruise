class_name TaxiSettings
extends Resource
## Taxi orders: a passenger hails from the right sidewalk, rides a set distance, and pays
## when dropped off at the marked bay. Pull in close to the curb for both.

@export_range(0.0, 20000.0) var first_order_metres: float = 350.0
## Wait after a ride ends (or a hail is missed) before the next passenger hails.
@export_range(50.0, 20000.0) var order_metres_min: float = 400.0
@export_range(50.0, 20000.0) var order_metres_max: float = 700.0
@export_range(50.0, 5000.0) var ride_metres_min: float = 250.0
@export_range(50.0, 5000.0) var ride_metres_max: float = 450.0
## The fare is one note of this face value for every started metres_per_note of the ride.
@export_range(1000, 100000) var fare_face_value: int = 10000
@export_range(10.0, 1000.0) var metres_per_note: float = 100.0
## The car's right edge must come this close to the curb while level with the spot.
@export_range(0.0, 60.0) var board_distance: float = 18.0
@export_range(20.0, 200.0) var zone_height: float = 64.0
@export var spawn_y: float = -60.0
@export var despawn_y: float = 900.0


func notes_for(ride_metres: float) -> int:
	return maxi(1, ceili(ride_metres / metres_per_note - 0.001))

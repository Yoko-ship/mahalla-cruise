class_name PassengerSettings
extends Resource
## Marshrutka stops on the right sidewalk. Passing close to the curb boards every passenger.

@export_range(0.0, 5000.0) var first_stop_metres: float = 200.0
@export_range(50.0, 5000.0) var stop_metres_min: float = 450.0
@export_range(50.0, 5000.0) var stop_metres_max: float = 750.0
@export_range(1, 4) var passengers_min: int = 1
@export_range(1, 4) var passengers_max: int = 3
## Each passenger pays one note of this face value (game points follow the note).
@export_range(1000, 100000) var fare_face_value: int = 5000
## The car's right edge must come this close to the curb while level with the stop.
@export_range(0.0, 60.0) var board_distance: float = 18.0
## Height of the boarding zone beside the stop.
@export_range(20.0, 200.0) var zone_height: float = 64.0

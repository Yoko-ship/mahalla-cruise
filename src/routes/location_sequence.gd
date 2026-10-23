class_name LocationSequence
extends Resource
## Read-only scenery itinerary. Distances use actual car travel, including braking.

@export var locations: Array[StreetArt] = []
@export_range(50.0, 5000.0) var section_metres: float = 550.0
@export_range(1.0, 100.0) var transition_metres: float = 48.0

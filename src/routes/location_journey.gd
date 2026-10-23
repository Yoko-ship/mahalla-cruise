class_name LocationJourney
extends Node
## Owns the current district; the world passes its presentation state to scenery.

signal location_changed(name_key: String)

var current: StreetArt
var previous: StreetArt
var transition: float = 1.0
var index: int = 0
var _sequence: LocationSequence
var _start: int = 0
var _section: int = 0


func configure(route: RouteDefinition) -> void:
	_sequence = route.journey if route != null else null
	_start = route.start_location if route != null else 0
	_section = 0
	index = 0
	previous = null
	transition = 1.0
	current = route.street_art if route != null else null
	if _sequence != null and not _sequence.locations.is_empty():
		index = posmod(_start, _sequence.locations.size())
		current = _sequence.locations[index]
	location_changed.emit(current.name_key if current != null else "")


func advance(metres: float) -> void:
	if _sequence == null or _sequence.locations.is_empty():
		return
	var length := maxf(_sequence.section_metres, 1.0)
	var distance := maxf(metres, 0.0)
	var section := floori(distance / length)
	index = posmod(_start + section, _sequence.locations.size())
	current = _sequence.locations[index]
	transition = 1.0
	previous = null
	if section > 0:
		transition = clampf(fposmod(distance, length) / _sequence.transition_metres, 0.0, 1.0)
		if transition < 1.0:
			previous = _sequence.locations[posmod(index - 1, _sequence.locations.size())]
	if section != _section:
		_section = section
		location_changed.emit(current.name_key)

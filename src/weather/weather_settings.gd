class_name WeatherSettings
extends Resource
## Weather by the calendar: snow in winter, showers in spring and autumn, falling leaves in
## autumn, blossom at Navruz, and flag-coloured confetti on Independence Day. Weather only
## changes the look of the street, never points or handling.

@export_range(0.0, 1.0) var winter_snow_chance: float = 0.65
@export_range(0.0, 1.0) var spring_rain_chance: float = 0.3
@export_range(0.0, 1.0) var autumn_rain_chance: float = 0.2
@export_range(0.0, 1.0) var autumn_leaves_chance: float = 0.55
## Particles on screen for each kind.
@export var counts := {"rain": 70, "snow": 110, "leaves": 30, "blossom": 38, "confetti": 40}
## Share of road travel that also carries falling particles down the screen.
@export_range(0.0, 1.0) var travel_drift: float = 0.5

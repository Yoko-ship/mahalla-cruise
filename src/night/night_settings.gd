class_name NightSettings
extends Resource
## When night falls during a drive, how dark it gets, and the night points bonus.

@export_range(0.0, 100000.0) var start_metres: float = 1200.0
## Dusk lasts this far; the bonus starts once it is fully dark.
@export_range(1.0, 5000.0) var dusk_metres: float = 250.0
@export_range(0.0, 1.0) var darkness: float = 0.6
@export var tint := Color(0.03, 0.05, 0.16, 1)
## Extra points at night, as a percentage of money and close-call points.
@export_range(0, 500) var bonus_percent: int = 50
@export_range(50.0, 800.0) var beam_length: float = 300.0
@export_range(60.0, 800.0) var lamp_spacing: float = 260.0

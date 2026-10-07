class_name AudioSettings
extends Resource
## Music and horn levels; on/off choices are runtime state saved with the preferences.

@export_range(-40.0, 0.0) var music_volume_db: float = -15.0
@export_range(-40.0, 0.0) var horn_volume_db: float = -7.0
@export_range(0, 2000) var horn_cooldown_ms: int = 350

class_name PickupFeedbackSettings
extends Resource
## Defaults for pickup sound and haptics; toggles are runtime state on the feedback node.

@export var sound_enabled: bool = true
@export var haptics_enabled: bool = true
@export_range(-40.0, 0.0) var volume_db: float = -8.0
@export_range(0, 500) var minimum_interval_ms: int = 80
@export_range(1, 100) var som_vibration_ms: int = 16
@export_range(1, 100) var dollar_vibration_ms: int = 26
@export_range(0.0, 1.0) var vibration_strength: float = 0.25
@export_range(1, 100) var close_call_vibration_ms: int = 12
## Each combo step raises the close-call whoosh pitch by this fraction.
@export_range(0.0, 0.3) var close_call_pitch_step: float = 0.06
@export_range(1, 100) var bump_vibration_ms: int = 40

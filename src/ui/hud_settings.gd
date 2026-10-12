class_name HUDSettings
extends Resource
## Timing for the first-run instruction overlay, and the link added to shared results.

@export_range(1.0, 20.0) var first_hint_seconds: float = 6.0
## A store or channel link appended to results shared to Telegram; empty adds nothing.
@export var share_link: String = ""

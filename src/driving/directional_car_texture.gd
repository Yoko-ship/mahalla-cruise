class_name DirectionalCarTexture
extends AtlasTexture
## The inherited region is the straight preview. Frames share one camera and scale,
## ordered from steering left to right, with projected number-plate corners per frame.

@export var views: Array[Texture2D] = []
@export var plate_quads: Array[PackedVector2Array] = []
@export_range(1.0, 30.0) var steering_response: float = 18.0
@export var shadow_size := Vector2(38, 58)


func frame_for(heading: float) -> int:
	return roundi((clampf(heading, -1.0, 1.0) + 1.0) * 0.5 * (views.size() - 1))

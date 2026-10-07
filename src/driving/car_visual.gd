class_name CarVisual
extends Node2D
## Owns the aligned vehicle sprite and a soft lower-right ground shadow.

@onready var sprite: Sprite2D = $Sprite


func set_vehicle(texture: Texture2D, sprite_scale: float) -> void:
	sprite.texture = texture
	sprite.scale = Vector2(sprite_scale, sprite_scale)


func _draw() -> void:
	for layer in range(4):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.12, 0.14, 0.15, 0.045)
		shadow.set_corner_radius_all(12)
		var spread := float(layer) * 2.0
		draw_style_box(
			shadow, Rect2(-20 - spread + 9, -25 - spread + 12, 40 + spread * 2, 60 + spread * 2)
		)

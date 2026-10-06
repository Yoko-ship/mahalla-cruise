class_name TrafficVisual
extends Node2D
## Sedan artwork shares the player's camera, materials, and light direction.

const VEHICLES: Texture2D = preload("res://assets/cars/vehicles_aligned.png")
const SEDAN_REGION := Rect2(1080, 225, 425, 520)

var paint := Color("b1c6ce")


func _draw() -> void:
	for layer in range(4):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.12, 0.14, 0.15, 0.045)
		shadow.set_corner_radius_all(11)
		var spread := float(layer) * 2.0
		draw_style_box(
			shadow, Rect2(-21 - spread + 8, -23 - spread + 10, 42 + spread * 2, 56 + spread * 2)
		)
	draw_texture_rect_region(VEHICLES, Rect2(-25, -36, 50, 72), SEDAN_REGION, paint)

class_name TrafficVisual
extends Node2D
## Traffic artwork shares the player's camera, materials, and light direction.

const VEHICLES: Texture2D = preload("res://assets/cars/vehicles_aligned.png")
const SEDAN_REGION := Rect2(1080, 225, 425, 520)

const PAINT_SHADER: Shader = preload("res://src/driving/car_paint.gdshader")

var sprite := Sprite2D.new()
var _shadow_size := Vector2(36, 54)


func _ready() -> void:
	add_child(sprite)
	var paint_material := ShaderMaterial.new()
	paint_material.shader = PAINT_SHADER
	sprite.material = paint_material


func set_appearance(texture: Texture2D, paint: Color, max_size: Vector2) -> void:
	if texture == null:
		var fallback := AtlasTexture.new()
		fallback.atlas = VEHICLES
		fallback.region = SEDAN_REGION
		texture = fallback
	sprite.texture = texture
	var size := texture.get_size()
	var fit := minf(max_size.x / size.x, max_size.y / size.y)
	sprite.scale = Vector2.ONE * fit
	(sprite.material as ShaderMaterial).set_shader_parameter("paint", paint)
	_shadow_size = size * fit * Vector2(0.78, 0.74)
	queue_redraw()


func _draw() -> void:
	for layer in range(5):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.06, 0.07, 0.08, 0.065)
		shadow.set_corner_radius_all(12)
		var size := _shadow_size + Vector2.ONE * float(layer) * 2.0
		draw_style_box(shadow, Rect2(Vector2(2, 7) - size * 0.5, size))

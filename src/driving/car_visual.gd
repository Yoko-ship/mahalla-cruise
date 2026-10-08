class_name CarVisual
extends Node2D
## Owns the aligned vehicle sprite, a soft lower-right ground shadow, and the small
## number plate on the rear bumper.

const PAINT_SHADER: Shader = preload("res://src/driving/car_paint.gdshader")
const PLATE_SIZE := Vector2(15, 5)

var plate: String = ""
var _plate_y: float = 30.0
var _plate_layer := Node2D.new()

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_child(_plate_layer)
	_plate_layer.draw.connect(_draw_plate)


func set_vehicle(texture: Texture2D, sprite_scale: float, paint: Color) -> void:
	sprite.texture = texture
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	if not sprite.material is ShaderMaterial:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = PAINT_SHADER
	sprite.material.set_shader_parameter("paint", paint)
	if texture != null:
		# The rear bumper sits just above the bottom edge of the rear-view sprite.
		_plate_y = texture.get_height() * sprite_scale * 0.5 - 8.0
	_plate_layer.queue_redraw()


func set_plate(code: String) -> void:
	plate = code
	_plate_layer.queue_redraw()


func _draw_plate() -> void:
	if plate.is_empty():
		return
	var box := Rect2(Vector2(-PLATE_SIZE.x * 0.5, _plate_y), PLATE_SIZE)
	_plate_layer.draw_rect(box.grow(0.6), Color(0.1, 0.1, 0.12, 0.9))
	_plate_layer.draw_rect(box, Color(0.97, 0.97, 0.95))
	_plate_layer.draw_rect(Rect2(box.position, Vector2(3.5, PLATE_SIZE.y)), Color(0.75, 0.78, 0.8))
	_plate_layer.draw_rect(Rect2(box.end.x - 3.0, box.position.y + 0.8, 2.2, 1.6), Color("1eb3e6"))


func _draw() -> void:
	for layer in range(4):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.12, 0.14, 0.15, 0.045)
		shadow.set_corner_radius_all(12)
		var spread := float(layer) * 2.0
		draw_style_box(
			shadow, Rect2(-20 - spread + 9, -25 - spread + 12, 40 + spread * 2, 60 + spread * 2)
		)

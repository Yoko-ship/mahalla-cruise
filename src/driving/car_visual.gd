class_name CarVisual
extends Node2D
## Owns the aligned vehicle sprite, a soft lower-right ground shadow, and the small
## number plate on the rear bumper.

const PAINT_SHADER: Shader = preload("res://src/driving/car_paint.gdshader")
const PLATE_SIZE := Vector2(15, 5)

var plate: String = ""
var _plate_y: float = 30.0
var _plate_layer := Node2D.new()
var _directional: DirectionalCarTexture
var _heading: float = 0.0
var _frame: int = -1

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_child(_plate_layer)
	_plate_layer.draw.connect(_draw_plate)


func set_vehicle(texture: Texture2D, sprite_scale: float, paint: Color) -> void:
	_directional = texture as DirectionalCarTexture
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
	reset_steering()
	queue_redraw()


func has_directional_art() -> bool:
	return _directional != null and not _directional.views.is_empty()


func set_steering(heading: float, delta: float) -> void:
	if not has_directional_art():
		return
	_heading = lerpf(
		_heading,
		clampf(heading, -1.0, 1.0),
		1.0 - exp(-_directional.steering_response * maxf(delta, 0.0))
	)
	_show_heading()


func reset_steering() -> void:
	_heading = 0.0
	_frame = -1
	_show_heading()


func _show_heading() -> void:
	if not has_directional_art():
		return
	var next := _directional.frame_for(_heading)
	if next == _frame:
		return
	_frame = next
	sprite.texture = _directional.views[_frame]
	_plate_layer.queue_redraw()


func set_plate(code: String) -> void:
	plate = code
	_plate_layer.queue_redraw()


func _draw_plate() -> void:
	if plate.is_empty():
		return
	if has_directional_art() and _frame < _directional.plate_quads.size():
		var corners := _directional.plate_quads[_frame]
		var points := PackedVector2Array()
		for corner in corners:
			points.append((corner - sprite.texture.get_size() * 0.5) * sprite.scale)
		_plate_layer.draw_colored_polygon(points, Color(0.83, 0.85, 0.81))
		var flag := PackedVector2Array(
			[
				points[0].lerp(points[1], 0.82),
				points[0].lerp(points[1], 0.96),
				points[3].lerp(points[2], 0.96),
				points[3].lerp(points[2], 0.82)
			]
		)
		_plate_layer.draw_colored_polygon(flag, Color("5292a3"))
		return
	var box := Rect2(Vector2(-PLATE_SIZE.x * 0.5, _plate_y), PLATE_SIZE)
	_plate_layer.draw_rect(box.grow(0.6), Color(0.1, 0.1, 0.12, 0.9))
	_plate_layer.draw_rect(box, Color(0.97, 0.97, 0.95))
	_plate_layer.draw_rect(Rect2(box.position, Vector2(3.5, PLATE_SIZE.y)), Color(0.75, 0.78, 0.8))
	_plate_layer.draw_rect(Rect2(box.end.x - 3.0, box.position.y + 0.8, 2.2, 1.6), Color("1eb3e6"))


func _draw() -> void:
	if has_directional_art():
		for layer in range(5):
			var shape := StyleBoxFlat.new()
			shape.bg_color = Color(0.06, 0.07, 0.08, 0.075)
			shape.set_corner_radius_all(18)
			var size := _directional.shadow_size + Vector2.ONE * layer * 2.0
			draw_style_box(shape, Rect2(Vector2(2, 9) - size * 0.5, size))
		return
	for layer in range(4):
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.12, 0.14, 0.15, 0.045)
		shadow.set_corner_radius_all(12)
		var spread := float(layer) * 2.0
		draw_style_box(
			shadow, Rect2(-20 - spread + 9, -25 - spread + 12, 40 + spread * 2, 60 + spread * 2)
		)

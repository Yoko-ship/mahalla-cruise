extends SceneTree
## Build temporary garage sprites by repainting and resizing the existing painted sedan.
## Testing art only: shapes are the traffic sedan, not real Matiz, Cobalt, or Gentra bodies.

const SOURCE: String = "res://assets/cars/vehicles_aligned.png"
const OUTPUT: String = "res://assets/cars/placeholder_roster.png"
# Tight bounds of the silver sedan inside the shared vehicle atlas.
const SEDAN := Rect2i(1087, 235, 412, 502)
# Licence plate inside SEDAN; it keeps its original light color.
const PLATE := Rect2i(142, 354, 124, 38)
const GAP: int = 40
# Sizes at sprite_scale 0.1 match each car's collision box like the Damas does.
const CARS: Array[Dictionary] = [
	{"id": "matiz", "size": Vector2i(400, 600), "paint": "red"},
	{"id": "cobalt", "size": Vector2i(440, 780), "paint": "pearl"},
	{"id": "gentra", "size": Vector2i(460, 800), "paint": "black"},
]


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if atlas == null:
		push_error("Cannot read " + SOURCE)
		quit(1)
		return
	atlas.convert(Image.FORMAT_RGBA8)
	var sedan := atlas.get_region(SEDAN)
	var width := GAP
	var height := 0
	for car in CARS:
		width += car.size.x + GAP
		height = maxi(height, car.size.y)
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var x := GAP
	for car in CARS:
		var sprite := _repaint(sedan, car.paint)
		sprite.resize(car.size.x, car.size.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, car.size), Vector2i(x, 0))
		print("%s region: Rect2(%d, 0, %d, %d)" % [car.id, x, car.size.x, car.size.y])
		x += car.size.x + GAP
	var error := sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Cannot write %s: %d" % [OUTPUT, error])
	quit(1 if error != OK else 0)


func _repaint(source: Image, paint: String) -> Image:
	var image := source.duplicate() as Image
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.0 or PLATE.has_point(Vector2i(x, y)):
				continue
			# Soft mask: only light, unsaturated body paint; lamps, glass and tyres stay.
			var weight := (1.0 - smoothstep(0.10, 0.22, color.s)) * smoothstep(0.28, 0.38, color.v)
			if weight <= 0.0:
				continue
			var shade := clampf((color.v - 0.28) / 0.72, 0.0, 1.0)
			var painted := _paint(paint, shade)
			var mixed := color.lerp(painted, weight)
			image.set_pixel(x, y, Color(mixed.r, mixed.g, mixed.b, color.a))
	return image


func _paint(paint: String, shade: float) -> Color:
	match paint:
		"black":
			# Lifted highlights keep the black body readable on dark asphalt.
			var value := 0.06 + 0.34 * pow(shade, 2.0)
			return Color(value, value * 1.03, value * 1.1)
		"pearl":
			var value := 0.74 + 0.26 * shade
			return Color(value, value * 0.985, value * 0.95)
		_:
			return Color.from_hsv(0.99, 0.8, 0.32 + 0.6 * shade)

extends SceneTree
## Build temporary garage sprites by resizing the existing painted silver sedan.
## Body color comes from the runtime paint shader, so the sprites stay neutral silver.
## Testing art only: shapes are the traffic sedan, not real Matiz, Cobalt, or Gentra bodies.

const SOURCE: String = "res://assets/cars/vehicles_aligned.png"
const OUTPUT: String = "res://assets/cars/placeholder_roster.png"
# Tight bounds of the silver sedan inside the shared vehicle atlas.
const SEDAN := Rect2i(1087, 235, 412, 502)
# Licence plate inside SEDAN. A light cream tint keeps the paint shader off it.
const PLATE := Rect2i(142, 354, 124, 38)
const PLATE_TINT := Color(1.0, 0.93, 0.72)
const GAP: int = 40
# Sizes at sprite_scale 0.1 match each car's collision box like the Damas does.
const CARS: Array[Dictionary] = [
	{"id": "matiz", "size": Vector2i(400, 600)},
	{"id": "cobalt", "size": Vector2i(440, 780)},
	{"id": "gentra", "size": Vector2i(460, 800)},
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
	for y in range(PLATE.position.y, PLATE.end.y):
		for x in range(PLATE.position.x, PLATE.end.x):
			var color := sedan.get_pixel(x, y)
			if color.v > 0.6 and color.s < 0.2:
				sedan.set_pixel(x, y, Color(color * PLATE_TINT, color.a))
	var width := GAP
	var height := 0
	for car in CARS:
		width += car.size.x + GAP
		height = maxi(height, car.size.y)
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var x := GAP
	for car in CARS:
		var sprite := sedan.duplicate() as Image
		sprite.resize(car.size.x, car.size.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, car.size), Vector2i(x, 0))
		print("%s region: Rect2(%d, 0, %d, %d)" % [car.id, x, car.size.x, car.size.y])
		x += car.size.x + GAP
	var error := sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Cannot write %s: %d" % [OUTPUT, error])
	quit(1 if error != OK else 0)

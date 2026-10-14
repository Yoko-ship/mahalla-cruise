extends SceneTree
## Pack the Blender renders of the garage cars (scripts/blender/roster_cars.py writes them to
## build/roster_renders/) into one atlas. Each render is cropped to the car and scaled so that
## at sprite_scale 0.1 its length matches the car's collision box, like the Damas. The region
## printed for each car is what default_garage.tres uses.

const SOURCE_DIR: String = "res://build/roster_renders/"
const OUTPUT: String = "res://assets/cars/roster_cars.png"
const GAP: int = 40
# Atlas pixels at sprite_scale 0.1: height is ten times the collision length; width is capped
# at the collision width plus 10 game pixels for mirrors, like the Damas sprite.
const CARS: Array[Dictionary] = [
	{"id": "matiz", "height": 600, "max_width": 440},
	{"id": "cobalt", "height": 780, "max_width": 480},
	{"id": "gentra", "height": 800, "max_width": 500},
	{"id": "spark", "height": 620, "max_width": 440},
	{"id": "nexia", "height": 760, "max_width": 500},
	{"id": "malibu", "height": 840, "max_width": 520},
]


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	var sprites: Array[Image] = []
	for car in CARS:
		var path := ProjectSettings.globalize_path(SOURCE_DIR + car.id + ".png")
		var sprite := Image.load_from_file(path)
		if sprite == null or sprite.is_empty():
			push_error("Cannot read %s; render it with scripts/blender/roster_cars.py" % path)
			quit(1)
			return
		sprite.convert(Image.FORMAT_RGBA8)
		sprite = sprite.get_region(sprite.get_used_rect())
		var height: int = car.height
		var width := roundi(sprite.get_width() * float(height) / sprite.get_height())
		width = mini(width, car.max_width)
		sprite.resize(width, height, Image.INTERPOLATE_LANCZOS)
		sprites.append(sprite)
	var sheet_width := GAP
	var sheet_height := 0
	for sprite in sprites:
		sheet_width += sprite.get_width() + GAP
		sheet_height = maxi(sheet_height, sprite.get_height())
	var sheet := Image.create_empty(sheet_width, sheet_height, false, Image.FORMAT_RGBA8)
	var x := GAP
	for index in range(CARS.size()):
		var sprite := sprites[index]
		sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(x, 0))
		print(
			(
				"%s region: Rect2(%d, 0, %d, %d)"
				% [CARS[index].id, x, sprite.get_width(), sprite.get_height()]
			)
		)
		x += sprite.get_width() + GAP
	var error := sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Cannot write %s: %d" % [OUTPUT, error])
	quit(1 if error != OK else 0)

extends SceneTree
## Pack the Blender renders of the garage cars (scripts/blender/roster_cars.py writes them to
## build/roster_renders/) into one atlas. Each render is cropped to the car and scaled so that
## at sprite_scale 0.1 its length matches the car's collision box, like the Damas. The region
## printed for each car is what default_garage.tres uses.
## With -- --painted, pack assets/cars/painted/ into roster_painted.png instead.

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
	var painted := "--painted" in OS.get_cmdline_user_args()
	var source_dir := "res://assets/cars/painted/" if painted else SOURCE_DIR
	var output := "res://assets/cars/roster_painted.png" if painted else OUTPUT
	var sprites: Array[Image] = []
	for car in CARS:
		var path := ProjectSettings.globalize_path(source_dir + car.id + ".png")
		var sprite := Image.load_from_file(path)
		if sprite == null or sprite.is_empty():
			push_error("Cannot read source car image: %s" % path)
			quit(1)
			return
		sprite.convert(Image.FORMAT_RGBA8)
		var bounds := _visible_bounds(sprite) if painted else sprite.get_used_rect()
		sprite = sprite.get_region(bounds)
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
	var error := sheet.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Cannot write %s: %d" % [output, error])
	quit(1 if error != OK else 0)


## Generated alpha can contain almost invisible specks far outside the car. Frame the
## solid silhouette, keeping two source pixels around it for the antialiased edge.
func _visible_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5:
				continue
			first.x = mini(first.x, x)
			first.y = mini(first.y, y)
			last.x = maxi(last.x, x)
			last.y = maxi(last.y, y)
	if last.x < 0:
		return image.get_used_rect()
	return Rect2i(first, last - first + Vector2i.ONE).grow(2).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)

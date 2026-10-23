extends SceneTree
## Pack uniformly scaled Blender renders, leaving transparent gutters for mipmaps.

const CARS: Array[String] = ["matiz", "spark", "nexia", "gentra", "malibu"]
const OUTPUT := "res://assets/cars/traffic_realistic.png"
const HEIGHT := 720
const PAD := 8


func _initialize() -> void:
	var images: Array[Image] = []
	var width := 0
	for car in CARS:
		var source := Image.load_from_file("res://build/traffic_renders/%s.png" % car)
		assert(source != null and not source.is_empty(), "Missing render: " + car)
		source.convert(Image.FORMAT_RGBA8)
		var crop := source.get_region(source.get_used_rect())
		var fit := float(HEIGHT) / crop.get_height()
		crop.resize(roundi(crop.get_width() * fit), HEIGHT, Image.INTERPOLATE_LANCZOS)
		images.append(crop)
		width += crop.get_width() + PAD * 2
	var atlas := Image.create_empty(width, HEIGHT + PAD * 2, false, Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute("res://src/traffic/art")
	var x := 0
	for index in CARS.size():
		var crop := images[index]
		var frame_width := crop.get_width() + PAD * 2
		atlas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(x + PAD, PAD))
		var file := FileAccess.open("res://src/traffic/art/%s.tres" % CARS[index], FileAccess.WRITE)
		file.store_string(
			(
				'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
				+ '[ext_resource type="Texture2D" path="%s" id="1"]\n\n' % OUTPUT
				+ '[resource]\nresource_name = "%s"\natlas = ExtResource("1")\n' % CARS[index]
				+ (
					"region = Rect2(%d, 0, %d, %d)\nfilter_clip = true\n"
					% [x, frame_width, HEIGHT + PAD * 2]
				)
			)
		)
		print("Packed %s: %d by %d" % [CARS[index], frame_width, HEIGHT + PAD * 2])
		x += frame_width
	assert(atlas.save_png(OUTPUT) == OK)
	quit()

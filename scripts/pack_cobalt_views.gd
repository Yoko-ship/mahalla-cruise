extends SceneTree
## Pack Blender views using one uniform scale and shared pivot; never squeeze the body.

const SOURCE := "res://build/cobalt_driving/"
const OUTPUT := "res://assets/cars/cobalt_driving.png"
const RESOURCE := "res://src/driving/cobalt_art.tres"
const COUNT := 5
const CENTER := 2
const HEIGHT := 780


func _initialize() -> void:
	var images: Array[Image] = []
	var bounds: Array[Rect2i] = []
	var common := Rect2i()
	for index in COUNT:
		var path := ProjectSettings.globalize_path(SOURCE + "%d.png" % index)
		var source := Image.load_from_file(path)
		assert(source != null and not source.is_empty(), "Missing Blender view: " + path)
		source.convert(Image.FORMAT_RGBA8)
		images.append(source)
		bounds.append(source.get_used_rect())
		common = bounds.back() if index == 0 else common.merge(bounds.back())
	common = common.grow(3)
	var scale := float(HEIGHT) / bounds[CENTER].size.y
	var frame := Vector2i(roundi(common.size.x * scale), roundi(common.size.y * scale))
	var atlas := Image.create_empty((frame.x + 8) * COUNT, frame.y, false, Image.FORMAT_RGBA8)
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "frames.json"))
	var parts: Array[String] = [
		(
			'[gd_resource type="AtlasTexture" script_class="DirectionalCarTexture" '
			+ "load_steps=8 format=3]"
		),
		'[ext_resource type="Script" path="res://src/driving/directional_car_texture.gd" id="1"]',
		'[ext_resource type="Texture2D" path="%s" id="2"]' % OUTPUT,
	]
	var views: Array[String] = []
	var quads: Array[String] = []
	for index in COUNT:
		var crop := images[index].get_region(common)
		crop.resize(frame.x, frame.y, Image.INTERPOLATE_LANCZOS)
		var x := index * (frame.x + 8)
		atlas.blit_rect(crop, Rect2i(Vector2i.ZERO, frame), Vector2i(x, 0))
		parts.append(
			(
				'[sub_resource type="AtlasTexture" id="view%d"]\natlas = ExtResource("2")\n' % index
				+ "region = Rect2(%d, 0, %d, %d)" % [x, frame.x, frame.y]
			)
		)
		views.append('SubResource("view%d")' % index)
		var points: Array[String] = []
		for point: Array in meta[index].plate:
			var p := (Vector2(point[0], point[1]) - Vector2(common.position)) * scale
			points.append("%.3f, %.3f" % [p.x, p.y])
		quads.append("PackedVector2Array(%s)" % ", ".join(points))
	var center := Rect2(
		Vector2(bounds[CENTER].position - common.position) * scale,
		Vector2(bounds[CENTER].size) * scale
	)
	center.position.x += CENTER * (frame.x + 8)
	parts.append(
		(
			'[resource]\nscript = ExtResource("1")\natlas = ExtResource("2")\n'
			+ (
				"region = Rect2(%.3f, %.3f, %.3f, %.3f)\n"
				% [center.position.x, center.position.y, center.size.x, center.size.y]
			)
			+ "views = Array[Texture2D]([%s])\n" % ", ".join(views)
			+ "plate_quads = Array[PackedVector2Array]([%s])" % ", ".join(quads)
		)
	)
	assert(atlas.save_png(ProjectSettings.globalize_path(OUTPUT)) == OK)
	var file := FileAccess.open(RESOURCE, FileAccess.WRITE)
	file.store_string("\n\n".join(parts) + "\n")
	print(
		"Packed five views at uniform scale %.4f; frame %s, center %s" % [scale, frame, center.size]
	)
	quit()

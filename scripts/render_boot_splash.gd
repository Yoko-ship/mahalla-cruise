extends SceneTree
## Rebuild the boot PNG from the existing vector icon and native Godot typography.

const OUTPUT: String = "res://assets/branding/boot_splash.png"
const BACKGROUND := Color("203e38")


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1024, 1024)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas := Control.new()
	canvas.size = Vector2(512, 512)
	canvas.scale = Vector2(2, 2)
	view.add_child(canvas)
	var background := ColorRect.new()
	background.size = canvas.size
	background.color = BACKGROUND
	canvas.add_child(background)
	var vector_image := Image.new()
	var error := vector_image.load_svg_from_string(
		FileAccess.get_file_as_string("res://assets/icon.svg"), 2.0
	)
	if error != OK:
		push_error("Cannot rasterize the source icon: %d" % error)
		quit(1)
		return
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(vector_image)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(176, 64)
	icon.size = Vector2(160, 160)
	canvas.add_child(icon)
	var title := Label.new()
	title.text = "Mahalla\nCruise"
	title.position = Vector2(48, 263)
	title.size = Vector2(416, 150)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("fff5d9"))
	canvas.add_child(title)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	error = view.get_texture().get_image().save_png(OUTPUT)
	view.free()
	if error != OK:
		push_error("Cannot save the boot splash: %d" % error)
		quit(1)
		return
	print("Rendered " + OUTPUT)
	quit()

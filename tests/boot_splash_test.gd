extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	var path: String = ProjectSettings.get_setting("application/boot_splash/image")
	_check(path.ends_with(".png"), "Early boot uses the supported PNG format")
	var splash := Image.new()
	var error := splash.load(path)
	_check(error == OK, "The boot image is readable before scene resources load")
	if error == OK:
		_check(splash.get_size() == Vector2i(1024, 1024), "Splash has sufficient phone resolution")
		_check(not splash.is_invisible(), "The boot image contains visible artwork")
		var color: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
		var matching := true
		for point in [Vector2i(0, 0), Vector2i(1023, 0), Vector2i(0, 1023), Vector2i(1023, 1023)]:
			matching = matching and splash.get_pixelv(point).is_equal_approx(color)
		_check(matching, "Splash corners blend into the phone's surrounding background")
	_check(
		ProjectSettings.get_setting("application/boot_splash/minimum_display_time") == 0,
		"Branding never adds an artificial startup delay"
	)
	if failures == 0:
		print(
			(
				"PASS: branded boot asset, seamless background, and no artificial delay (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

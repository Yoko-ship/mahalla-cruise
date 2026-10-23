extends SceneTree

const ART: DirectionalCarTexture = preload("res://src/driving/cobalt_art.tres")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")
const PLAYER: PackedScene = preload("res://src/driving/player_car.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_art()
	var car := PLAYER.instantiate() as PlayerCar
	root.add_child(car)
	car.set_physics_process(false)
	var cobalt := GARAGE.find("cobalt")
	car.apply_car(cobalt.settings, cobalt.texture, cobalt.sprite_scale, Color.WHITE)
	car.reset_run(Vector2(216, 600))
	car.set_physics_process(false)
	car.configure_bounds(124, 308)
	var visual := car.visual
	_check(visual.sprite.texture == ART.views[2], "Applying/resetting a car selects straight view")
	car.set_plate("01A777AA")
	car.steering.steering_delta.emit(-100.0)
	for frame in 5:
		car.advance(1.0 / 60.0)
	_check(car.position.x < 216, "Real steering still moves left")
	_check(visual.sprite.texture == ART.views[0], "Left travel reveals the left steering view")
	_check(is_zero_approx(car.rotation), "Directional art is not rotated again as a flat picture")
	var contact := car.collision_bounds()
	_check(
		contact.size == cobalt.settings.collision_half_size * 2, "Artwork never changes collision"
	)
	car.set_driving_enabled(false)
	var paused := visual.sprite.texture
	car.advance(1.0)
	_check(visual.sprite.texture == paused, "Pause freezes the current view")
	_check(car.collision_bounds() == contact, "Pause freezes movement too")
	car.set_driving_enabled(true)
	car.set_physics_process(false)
	car.steering.steering_delta.emit(200.0)
	for frame in 8:
		car.advance(1.0 / 60.0)
	_check(visual.sprite.texture == ART.views[4], "Right travel reveals the right steering view")
	for frame in 90:
		car.advance(1.0 / 60.0)
	_check(visual.sprite.texture == ART.views[2], "Stopped steering settles straight")
	visual.set_steering(-1.0, 1.0)
	car.reset_run(Vector2(216, 600))
	car.set_physics_process(false)
	_check(visual.sprite.texture == ART.views[2], "Restart clears the old heading")
	_check(visual.plate == "01A777AA", "Turning and restart keep the selected plate")
	var matiz := GARAGE.find("matiz")
	car.apply_car(matiz.settings, matiz.texture, matiz.sprite_scale, Color.RED)
	_check(not visual.has_directional_art(), "Switching to a static car clears directional state")
	visual.set_steering(1.0, 1.0)
	_check(visual.sprite.texture == matiz.texture, "Static cars keep their original artwork")
	car.free()
	if failures == 0:
		print(
			(
				"PASS: directional car art, steering, plates, pause, reset, and fallback (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_art() -> void:
	_check(
		ART.views.size() == 5 and ART.plate_quads.size() == 5,
		"Five views have five plate projections"
	)
	_check(ART.frame_for(-5) == 0 and ART.frame_for(5) == 4, "Extreme steering is clamped")
	_check(ART.frame_for(0) == 2, "Neutral heading selects the center")
	var rectangles: Array[Rect2] = []
	for index in ART.views.size():
		var view := ART.views[index] as AtlasTexture
		_check(view.region.size == ART.views[2].get_size(), "Views share canvas size and pivot")
		_check(view.atlas == ART.atlas, "All views come from the same atlas")
		for previous in rectangles:
			_check(not previous.intersects(view.region), "Steering frames never overlap")
		rectangles.append(view.region)
		var quad := ART.plate_quads[index]
		_check(quad.size() == 4, "Plate has four projected corners")
		for corner in quad:
			_check(
				Rect2(Vector2.ZERO, view.get_size()).has_point(corner), "Plate stays inside frame"
			)
		_check(quad[0].y < quad[3].y and quad[1].y < quad[2].y, "Plate projection is upright")
	_check(ART.plate_quads[0] != ART.plate_quads[4], "The plate follows the turning bumper")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

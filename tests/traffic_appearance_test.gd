extends SceneTree

const TRAFFIC: PackedScene = preload("res://src/traffic/traffic.tscn")
const CAR: PackedScene = preload("res://src/traffic/traffic_car.tscn")
const SETTINGS: TrafficSettings = preload("res://src/traffic/default_traffic.tres")
const ROAD: RoadSettings = preload("res://src/road/default_road.tres")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_models := SETTINGS.models.duplicate()
	var original_paints := SETTINGS.paints.duplicate()
	var traffic := TRAFFIC.instantiate() as TrafficController
	root.add_child(traffic)
	traffic.configure(ROAD, SETTINGS)
	traffic._appearance_random.seed = 12345
	var roster_size := SETTINGS.models.size()
	_check(roster_size == 6, "Traffic uses the six models with realistic rendered art")
	var appearances := await _collect_spawns(traffic, roster_size * 3)
	_check(
		appearances.size() == roster_size * 3, "The drive exercises three complete model rotations"
	)
	var paints: Array[Color] = []
	for index in range(appearances.size()):
		var appearance: Array = appearances[index]
		if not paints.has(appearance[1]):
			paints.append(appearance[1])
		if index > 0:
			_check(appearance[0] != appearances[index - 1][0], "Adjacent spawns differ in model")
	for cycle in 3:
		var models: Array[Texture2D] = []
		for index in range(
			cycle * roster_size, mini((cycle + 1) * roster_size, appearances.size())
		):
			models.append(appearances[index][0])
		for model in SETTINGS.models:
			_check(models.count(model) == 1, "Every rotation includes each model once")
	_check(paints.size() >= 4, "Traffic uses visibly varied paint choices")
	traffic.configure(ROAD, SETTINGS)
	_check(traffic.vehicles.is_empty(), "Restart clears previous traffic")
	var restarted := await _collect_spawns(traffic, roster_size)
	for model in SETTINGS.models:
		var count := 0
		for appearance in restarted:
			count += int(appearance[0] == model)
		_check(count == 1, "Restart begins a fresh complete model rotation")
	_check(SETTINGS.models == original_models, "Spawning never shuffles the shared model resource")
	_check(SETTINGS.paints == original_paints, "Spawning never changes the shared paint palette")
	traffic.free()
	_test_render_state()
	_test_artwork()
	_test_empty_roster()
	if failures == 0:
		print(
			"PASS: traffic models, paint isolation, proportions, and restart (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _collect_spawns(traffic: TrafficController, count: int) -> Array[Array]:
	var appearances: Array[Array] = []
	var last_id: int = 0
	for frame in 6000:
		traffic.advance(4.0, Rect2(-1000, -1000, 1, 1))
		if not traffic.vehicles.is_empty():
			var newest: TrafficCar = traffic.vehicles.back()
			if newest.get_instance_id() != last_id:
				last_id = newest.get_instance_id()
				var sprite := newest.visual.sprite
				var material := sprite.material as ShaderMaterial
				appearances.append([sprite.texture, material.get_shader_parameter("paint")])
				_check(
					newest.collision_bounds().size == SETTINGS.collision_half_size * 2.0,
					"Every model retains the existing collision size"
				)
				if appearances.size() == count:
					break
		if frame % 120 == 0:
			await process_frame
	return appearances


func _test_render_state() -> void:
	var first := CAR.instantiate() as TrafficCar
	var second := CAR.instantiate() as TrafficCar
	root.add_child(first)
	root.add_child(second)
	for model in SETTINGS.models:
		first.configure(SETTINGS.collision_half_size, Color.RED, model, SETTINGS.visual_size)
		second.configure(SETTINGS.collision_half_size, Color.BLUE, model, SETTINGS.visual_size)
		var sprite := first.visual.sprite
		var size := sprite.texture.get_size() * sprite.scale
		_check(
			is_equal_approx(sprite.scale.x, sprite.scale.y), "Car proportions are never stretched"
		)
		_check(
			size.x <= SETTINGS.visual_size.x + 0.01 and size.y <= 72.01,
			"Mirrors fit the visual allowance while body length matches collisions"
		)
		_check(size.y >= 70.0, "Visible car length closely matches its collision box")
		_check(sprite.material != second.visual.sprite.material, "Each car owns its paint material")
		_check(
			(sprite.material as ShaderMaterial).get_shader_parameter("paint") == Color.RED,
			"Recoloring another car leaves this car's paint unchanged"
		)
		var texture := sprite.texture
		first.advance(100.0)
		first.mark_contacted()
		_check(sprite.texture == texture, "Movement and contact preserve the chosen model")
	first.free()
	second.free()


func _test_artwork() -> void:
	for texture in SETTINGS.models:
		var atlas := texture as AtlasTexture
		_check(atlas != null, "Each traffic model uses an atlas sprite")
		var path := atlas.atlas.resource_path
		_check(
			path.ends_with("traffic_realistic.png") or path.ends_with("cobalt_driving.png"),
			"Regular traffic uses consistent 3D-rendered artwork"
		)
		var image := atlas.atlas.get_image()
		_check(image.has_mipmaps(), "Rendered traffic supports smooth minification")
		_check(
			Rect2(Vector2.ZERO, image.get_size()).encloses(atlas.region),
			"Each car stays inside its source atlas"
		)
		var crop := image.get_region(Rect2i(atlas.region))
		var visible_height := float(crop.get_used_rect().size.y) / crop.get_height() * 72.0
		_check(visible_height >= 70.0, "Transparent padding does not shrink the visible body")


func _test_empty_roster() -> void:
	var traffic := TRAFFIC.instantiate() as TrafficController
	root.add_child(traffic)
	var settings := SETTINGS.duplicate() as TrafficSettings
	settings.models = []
	settings.paints = []
	traffic.configure(ROAD, settings)
	traffic.advance(settings.first_spawn_distance, Rect2(-1000, -1000, 1, 1))
	_check(traffic.vehicles.size() == 1, "An empty cosmetic roster still spawns traffic")
	_check(
		traffic.vehicles[0].visual.sprite.texture != null,
		"An empty roster has visible fallback art"
	)
	traffic.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

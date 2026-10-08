extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const GARAGE: GarageCatalogue = preload("res://src/garage/default_garage.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://paint_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_catalogue()
	_test_store_and_rules()
	await _test_garage_flow()
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			(
				"PASS: paint catalogue, purchases, shared ownership, and car shader (%d checks)"
				% checks
			)
		)
	quit(1 if failures else 0)


func _test_catalogue() -> void:
	var ids := {}
	for paint in GARAGE.paints:
		ids[paint.id] = paint
	_check(ids.size() == GARAGE.paints.size() and ids.size() == 6, "Six uniquely named paints")
	for car in GARAGE.cars:
		_check(GARAGE.find_paint(car.factory_paint) != null, "Factory paint exists: " + car.id)
	var factory := ["white", "cherry", "white", "black"]
	for index in range(GARAGE.cars.size()):
		_check(GARAGE.cars[index].factory_paint == factory[index], "Factory colors match the brief")
	for id in ["cherry", "black", "sky", "teal", "gold"]:
		_check(ids[id].price == 150, "Extra paints cost 150 points: " + id)


func _test_store_and_rules() -> void:
	_cleanup()
	var store := _store()
	var damas := GARAGE.find("damas")
	var matiz := GARAGE.find("matiz")
	_check(GarageRules.current_paint(GARAGE, store, damas).id == "white", "Damas starts white")
	_check(GarageRules.current_paint(GARAGE, store, matiz).id == "cherry", "Matiz starts cherry")
	_check(not GarageRules.choose_paint(GARAGE, store, damas, "sky"), "Paint needs enough points")
	store.complete_run(200)
	_check(GarageRules.choose_paint(GARAGE, store, damas, "sky"), "An affordable paint is bought")
	_check(store.wallet == 50 and store.owned_paints == ["sky"], "Buying spends the price once")
	_check(GarageRules.current_paint(GARAGE, store, damas).id == "sky", "The bought paint applies")
	_check(GarageRules.choose_paint(GARAGE, store, matiz, "sky"), "Owned paints work on any car")
	_check(store.wallet == 50, "Reusing a paint on another car is free")
	_check(GarageRules.choose_paint(GARAGE, store, damas, "white"), "Factory paint is always free")
	_check(not GarageRules.choose_paint(GARAGE, store, damas, "gold"), "Unaffordable paint refused")
	_check(not GarageRules.choose_paint(GARAGE, store, damas, "rainbow"), "Unknown paint refused")
	var reopened := _store()
	_check(reopened.owned_paints == ["sky"], "Bought paints survive relaunch")
	_check(GarageRules.current_paint(GARAGE, reopened, damas).id == "white", "Damas choice kept")
	_check(GarageRules.current_paint(GARAGE, reopened, matiz).id == "sky", "Matiz choice kept")
	store.free()
	reopened.free()
	_write(
		(
			'{"version": 1, "stats": {"best_score": 4}, "garage": {"owned_paints": "x",'
			+ ' "paints": {"damas": "gold", "matiz": 3}}}'
		)
	)
	store = _store()
	_check(store.best_score == 4 and store.owned_paints.is_empty(), "Damaged paints fall back")
	_check(GarageRules.current_paint(GARAGE, store, damas).id == "white", "Unowned paint not used")
	store.free()


func _test_garage_flow() -> void:
	_cleanup()
	_write('{"version": 1, "stats": {"best_score": 0}, "garage": {"wallet": 200}}')
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = _path
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	var sprite := game.world.player.visual.sprite
	var material := sprite.material as ShaderMaterial
	_check(material != null and material.shader == CarVisual.PAINT_SHADER, "The car uses paint")
	_check(_paint_of(sprite) == GARAGE.find_paint("white").color, "Damas is painted white")
	game.open_garage()
	var picker := game.hud.garage_menu.paints
	_check(picker.swatches.size() == 6, "The garage shows six swatches")
	var gold: Button = picker.swatches["gold"]
	_check(gold.text == "150" and not gold.disabled, "Unowned paints show their price")
	await _click(picker.swatches["sky"])
	_check(game.progress.wallet == 50, "A real click buys the paint")
	var sky := GARAGE.find_paint("sky").color
	_check(_paint_of(sprite) == sky, "The road car shows the new paint")
	_check(_paint_of(game.hud.menu.car) == sky, "The start screen car shows the new paint")
	var row := game.hud.garage_menu.row_for("damas")
	_check(_paint_of(row._preview) == sky, "The garage row preview shows the new paint")
	_check((picker.swatches["sky"] as Button).text == "", "Owned paints hide the price")
	_check((picker.swatches["teal"] as Button).disabled, "Unaffordable paints are disabled")
	game.hud.garage_menu.close()
	game.start_run()
	game.world.player.set_physics_process(false)
	game.garage_action("paint", "white")
	_check(_paint_of(sprite) == sky, "Paint cannot change during a drive")
	game.free()


func _paint_of(item: CanvasItem) -> Color:
	return (item.material as ShaderMaterial).get_shader_parameter("paint")


func _store() -> LocalProgressStore:
	var store := LocalProgressStore.new()
	store.save_path = _path
	store.load_progress()
	return store


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _write(text: String) -> void:
	_cleanup()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

class_name CruiseGame
extends Node2D
## Composes features and owns the shared driving clock. No drawing or raw input here.

enum RunState { START, PLAYING, PAUSED, GAME_OVER }

@export var road_settings: RoadSettings
@export var traffic_settings: TrafficSettings
@export var pickup_settings: PickupSettings
@export var garage: GarageCatalogue

var state: RunState = RunState.START
var distance_metres: float = 0.0
var is_game_over: bool:
	get:
		return state == RunState.GAME_OVER
var score: int = 0
var som_collected: int = 0
var dollars_collected: int = 0
var near_misses: int = 0
var car: CarDefinition
var _start_position: Vector2
var _focused: bool = true

@onready var road: RoadView = $Road
@onready var scenery: SceneryView = $Scenery
@onready var player: PlayerCar = $PlayerCar
@onready var traffic: TrafficController = $Traffic
@onready var pickups: PickupController = $Pickups
@onready var pickup_feedback: PickupFeedback = $PickupFeedback
@onready var progress: LocalProgressStore = $Progress
@onready var hud: CruiseHUD = $HUD
@onready var daily: DailyTasks = $DailyTasks
@onready var audio: GameAudio = $GameAudio


func _ready() -> void:
	assert(road_settings and traffic_settings and pickup_settings and garage, "Missing settings")
	_start_position = player.position
	road.configure(road_settings)
	scenery.configure(road_settings)
	player.configure_bounds(road_settings.left_edge, road_settings.right_edge)
	traffic.configure(road_settings, traffic_settings)
	traffic.contacted.connect(_on_traffic_contacted)
	traffic.near_missed.connect(_on_near_missed)
	pickups.configure(road_settings, pickup_settings)
	pickups.collected.connect(_on_money_collected)
	pickups.power_up_collected.connect(hud.show_power_up)
	pickups.power_up_collected.connect(
		func(_kind: String) -> void: pickup_feedback.play_pickup(true)
	)
	pickups.power_ups_changed.connect(hud.set_power_ups)
	hud.restart_requested.connect(restart_run)
	hud.play_requested.connect(start_run)
	hud.pause_requested.connect(pause_run)
	hud.resume_requested.connect(resume_run)
	hud.sound_toggled.connect(_set_option.bind("sound"))
	hud.haptics_toggled.connect(_set_option.bind("haptics"))
	hud.music_toggled.connect(_set_option.bind("music"))
	hud.horn_pressed.connect(audio.play_horn)
	hud.language_selected.connect(set_language)
	hud.garage_requested.connect(open_garage)
	hud.car_chosen.connect(choose_car)
	hud.paint_chosen.connect(choose_paint)
	hud.set_distance(distance_metres)
	hud.set_score(score, som_collected, dollars_collected, near_misses)
	progress.load_progress()
	_apply_preferences()
	_apply_car()
	daily.load_state(progress.daily)
	hud.set_daily(daily.entries())
	hud.set_best(progress.best_score)
	player.set_driving_enabled(false)
	player.hide()
	hud.show_start(progress.best_score)
	get_viewport().size_changed.connect(_layout_world)
	_layout_world()


func _layout_world() -> void:
	var design_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var viewport_size := get_viewport_rect().size
	position = (viewport_size - design_size) * 0.5
	var visible_bounds := Rect2(-position, viewport_size)
	road.set_view_bounds(visible_bounds)
	scenery.set_view_bounds(visible_bounds)
	traffic.set_vertical_padding(position.y)
	pickups.set_vertical_padding(position.y)
	pause_run()
	hud.set_playfield_offset(position)


func start_run() -> void:
	if state != RunState.START or not _focused:
		return
	var first_hint := not progress.driving_hint_seen
	if first_hint:
		progress.mark_driving_hint_seen()
	state = RunState.PLAYING
	player.show()
	player.set_driving_enabled(true)
	hud.begin_run(first_hint)
	audio.set_music_playing(true, true)


func pause_run() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.PAUSED
	player.set_driving_enabled(false)
	pickup_feedback.stop()
	audio.set_music_playing(false)
	hud.show_paused(score, distance_metres)


func resume_run() -> void:
	if state != RunState.PAUSED or not _focused:
		return
	state = RunState.PLAYING
	player.set_driving_enabled(true)
	audio.set_music_playing(true)
	hud.resume_run()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		pause_run()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pause_run()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if state != RunState.PLAYING:
		return
	var travel_pixels := road_settings.scroll_speed * car.settings.travel_speed_scale * delta
	distance_metres += travel_pixels / road_settings.pixels_per_metre
	road.advance(travel_pixels)
	scenery.advance(travel_pixels)
	traffic.set_distance(distance_metres)
	traffic.advance(travel_pixels, player.collision_bounds(), pickups.item_bounds())
	# Crash takes priority; no money can be awarded on or after the crash frame.
	if not is_game_over:
		pickups.advance(
			travel_pixels,
			player.collision_bounds(),
			traffic.blocking_bounds(),
			traffic_settings.relative_speed
		)
	hud.set_distance(distance_metres, delta)


func restart_run() -> void:
	if not is_game_over:
		return
	if not _focused:
		return
	state = RunState.PLAYING
	_reset_world()
	audio.set_music_playing(true, true)
	hud.reset_run()
	hud.set_score(score, som_collected, dollars_collected, near_misses)
	hud.set_best(progress.best_score, false, progress.has_unsaved_changes)


func open_garage() -> void:
	if not _focused:
		return
	if state == RunState.GAME_OVER:
		state = RunState.START
		_reset_world()
		player.set_driving_enabled(false)
		player.hide()
		hud.leave_results()
		hud.set_score(score, som_collected, dollars_collected, near_misses)
		hud.set_best(progress.best_score, false, progress.has_unsaved_changes)
	if state == RunState.START:
		hud.show_garage()


# Cars and paints change only between drives; purchases are checked against the wallet.
func choose_car(id: String) -> void:
	if state == RunState.START and GarageRules.choose_car(garage, progress, id):
		_apply_car()


func choose_paint(id: String) -> void:
	if state == RunState.START and GarageRules.choose_paint(garage, progress, car, id):
		_apply_car()


func _apply_car() -> void:
	car = GarageRules.current_car(garage, progress)
	assert(car != null, "Garage requires an available default car")
	var paint := GarageRules.current_paint(garage, progress, car).color
	player.apply_car(car.settings, car.texture, car.sprite_scale, paint)
	player.configure_bounds(road_settings.left_edge, road_settings.right_edge)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))


func _reset_world() -> void:
	distance_metres = 0.0
	score = 0
	som_collected = 0
	dollars_collected = 0
	near_misses = 0
	road.configure(road_settings)
	scenery.configure(road_settings)
	traffic.configure(road_settings, traffic_settings)
	pickups.configure(road_settings, pickup_settings)
	pickup_feedback.stop()
	player.reset_run(_start_position)


func _on_money_collected(points: int, note: BanknoteDefinition) -> void:
	if state != RunState.PLAYING:
		return
	dollars_collected += int(note.is_dollar)
	som_collected += int(not note.is_dollar)
	_add_points(points)
	hud.show_pickup(points, note.display_name())
	pickup_feedback.play_pickup(note.is_dollar)


func _on_near_missed(points: int, combo: int) -> void:
	if state != RunState.PLAYING:
		return
	near_misses += 1
	var earned := points * pickups.point_multiplier()
	_add_points(earned)
	hud.show_near_miss(earned, combo)
	pickup_feedback.play_close_call(combo)


func _add_points(points: int) -> void:
	score += points
	hud.set_score(score, som_collected, dollars_collected, near_misses)


func set_language(locale: String) -> void:
	progress.set_preferences(locale, progress.sound_enabled, progress.haptics_enabled)
	_apply_preferences()


func _set_option(enabled: bool, option: String) -> void:
	PreferenceRules.set_option(progress, option, enabled)
	_apply_preferences()


func _apply_preferences() -> void:
	PreferenceRules.apply(progress, pickup_feedback, audio, hud)


func _on_traffic_contacted() -> void:
	if state != RunState.PLAYING:
		return
	if pickups.absorb_crash():
		traffic.clear_contact()
		hud.show_power_up("shield_used")
		return
	state = RunState.GAME_OVER
	player.set_driving_enabled(false)
	pickup_feedback.stop()
	audio.set_music_playing(false)
	var notes := som_collected + dollars_collected
	var run := DailyTasks.summary(notes, near_misses, distance_metres, score)
	var task_rewards := daily.record_run(run)
	progress.stage_daily(daily.state, task_rewards)
	var new_best := progress.complete_run(score)
	hud.set_best(progress.best_score, new_best, progress.has_unsaved_changes)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))
	hud.set_daily(daily.entries())
	hud.show_game_over(
		distance_metres, traffic.last_contact_kind, score, progress.wallet, task_rewards
	)

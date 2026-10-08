class_name CruiseGame
extends Node2D
## Owns run state, scoring, and saved progress, and routes signals between the drive world,
## the HUD, and the other features. No drawing, raw input, or road objects here.

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
var refuels: int = 0
var car: CarDefinition
var _focused: bool = true

@onready var world: DriveWorld = $World
@onready var pickup_feedback: PickupFeedback = $PickupFeedback
@onready var progress: LocalProgressStore = $Progress
@onready var hud: CruiseHUD = $HUD
@onready var daily: DailyTasks = $DailyTasks
@onready var achievements: Achievements = $Achievements
@onready var audio: GameAudio = $GameAudio


func _ready() -> void:
	assert(road_settings and traffic_settings and pickup_settings and garage, "Missing settings")
	world.configure(road_settings, traffic_settings, pickup_settings)
	world.crashed.connect(_end_run)
	world.notice.connect(hud.show_feedback)
	world.near_missed.connect(_on_near_missed)
	world.money_collected.connect(_on_money_collected)
	world.power_up_collected.connect(_on_power_up_collected)
	world.power_ups_changed.connect(hud.set_power_ups)
	world.hazard_hit.connect(_on_hazard_hit)
	world.refueled.connect(_on_refueled)
	world.dashboard_changed.connect(hud.set_dashboard)
	hud.brake_changed.connect(world.set_braking)
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
	hud.upgrade_chosen.connect(choose_upgrade)
	_show_score()
	progress.load_progress()
	_apply_preferences()
	_apply_car()
	daily.load_state(progress.daily)
	achievements.load_state(progress.achievements)
	_show_lists()
	hud.set_best(progress.best_score)
	world.set_driving(false, false)
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
	world.set_view(Rect2(-position, viewport_size), position.y)
	pause_run()
	hud.set_playfield_offset(position)


func start_run() -> void:
	if state != RunState.START or not _focused:
		return
	var first_hint := not progress.driving_hint_seen
	if first_hint:
		progress.mark_driving_hint_seen()
	state = RunState.PLAYING
	world.set_driving(true)
	hud.begin_run(first_hint)
	audio.set_music_playing(true, true)


func pause_run() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.PAUSED
	world.set_driving(false)
	pickup_feedback.stop()
	audio.set_music_playing(false)
	hud.show_paused(score, distance_metres)


func resume_run() -> void:
	if state != RunState.PAUSED or not _focused:
		return
	state = RunState.PLAYING
	world.set_driving(true)
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
	var travel_pixels := world.travel_pixels(delta)
	distance_metres += travel_pixels / road_settings.pixels_per_metre
	world.advance(travel_pixels, distance_metres)
	hud.set_distance(distance_metres, delta)


func restart_run() -> void:
	if not is_game_over or not _focused:
		return
	state = RunState.PLAYING
	_reset_run()
	audio.set_music_playing(true, true)
	hud.reset_run()
	_show_score()
	hud.set_best(progress.best_score, false, progress.has_unsaved_changes)


func open_garage() -> void:
	if not _focused:
		return
	if state == RunState.GAME_OVER:
		state = RunState.START
		_reset_run()
		world.set_driving(false, false)
		hud.leave_results()
		_show_score()
		hud.set_best(progress.best_score, false, progress.has_unsaved_changes)
	if state == RunState.START:
		hud.show_garage()


# Cars, paints, and upgrades change only between drives; purchases are checked by the rules.
func choose_car(id: String) -> void:
	if state == RunState.START and GarageRules.choose_car(garage, progress, id):
		_apply_car()


func choose_paint(id: String) -> void:
	if state == RunState.START and GarageRules.choose_paint(garage, progress, car, id):
		_apply_car()


func choose_upgrade(id: String) -> void:
	if state == RunState.START and UpgradeRules.choose(garage, progress, car, id):
		_apply_car()


func _apply_car() -> void:
	car = GarageRules.current_car(garage, progress)
	assert(car != null, "Garage requires an available default car")
	var paint := GarageRules.current_paint(garage, progress, car).color
	var boosts := UpgradeRules.boosts(garage, progress, car)
	var settings := UpgradeRules.tuned_settings(car.settings, boosts)
	world.set_car(settings, car.texture, car.sprite_scale, paint, boosts)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))


func _reset_run() -> void:
	distance_metres = 0.0
	score = 0
	som_collected = 0
	dollars_collected = 0
	near_misses = 0
	refuels = 0
	world.reset_run(road_settings, traffic_settings, pickup_settings)
	pickup_feedback.stop()


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
	_add_points(points)
	if combo > 1:
		hud.show_feedback("near_miss_combo", [combo, points])
	else:
		hud.show_feedback("near_miss", [points])
	pickup_feedback.play_close_call(combo)


func _on_power_up_collected(kind: String) -> void:
	hud.show_feedback("power_" + kind)
	pickup_feedback.play_pickup(true)


func _on_hazard_hit(kind: String, penalty: int) -> void:
	if state != RunState.PLAYING:
		return
	score = maxi(0, score - penalty)
	_show_score()
	hud.show_feedback("hazard_" + kind, [penalty])
	pickup_feedback.play_bump(kind == "camera")


func _on_refueled() -> void:
	if state != RunState.PLAYING:
		return
	refuels += 1
	hud.show_feedback("refueled")
	pickup_feedback.play_pickup(true)


func _add_points(points: int) -> void:
	score += points
	_show_score()


func _show_score() -> void:
	hud.set_score(score, som_collected, dollars_collected, near_misses)


func _show_lists() -> void:
	hud.set_daily(daily.entries(), achievements.entries())


func set_language(locale: String) -> void:
	progress.set_preferences(locale, progress.sound_enabled, progress.haptics_enabled)
	_apply_preferences()


func _set_option(enabled: bool, option: String) -> void:
	PreferenceRules.set_option(progress, option, enabled)
	_apply_preferences()


func _apply_preferences() -> void:
	PreferenceRules.apply(progress, pickup_feedback, audio, hud)


## Ends the drive: a crash ("car" or "sheep") or an empty tank ("fuel").
func _end_run(kind: String) -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.GAME_OVER
	world.set_driving(false)
	pickup_feedback.stop()
	audio.set_music_playing(false)
	var notes := som_collected + dollars_collected
	var run := DailyTasks.summary(notes, near_misses, distance_metres, score, refuels)
	var task_rewards := daily.record_run(run)
	var unlocked := achievements.record_run(run)
	progress.stage_daily(daily.state, task_rewards)
	progress.stage_achievements(achievements.state, unlocked)
	var new_best := progress.complete_run(score)
	hud.set_best(progress.best_score, new_best, progress.has_unsaved_changes)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))
	_show_lists()
	hud.show_game_over(distance_metres, kind, score, progress.wallet, task_rewards, unlocked)

class_name CruiseGame
extends DriveScoring
## Owns the session (start, pause, second chance, results), saved progress, and the garage,
## and routes signals between the drive world, the HUD, and the other features. Scoring
## during a drive lives in DriveScoring. No drawing, raw input, or road objects here.

@export var easy_mode: bool = true
@export var easy_settings: EasyDriveSettings = preload("res://src/world/default_easy_drive.tres")
@export var road_settings: RoadSettings
@export var traffic_settings: TrafficSettings
@export var pickup_settings: PickupSettings
@export var garage: GarageCatalogue
@export var revival: RevivalSettings
@export var rivals: RivalLadder

var car: CarDefinition
var _focused: bool = true
## The second chance was taken this drive, and what ended the drive while it is offered.
var _revived: bool = false
var _end_kind: String = "car"

@onready var progress: LocalProgressStore = $Progress
@onready var daily: DailyTasks = $DailyTasks
@onready var achievements: Achievements = $Achievements
@onready var audio: GameAudio = $GameAudio


func _ready() -> void:
	assert(road_settings and traffic_settings and pickup_settings and garage, "Missing settings")
	assert(revival and rivals, "Missing second-chance or rival settings")
	world.easy_settings = easy_settings if easy_mode else null
	world.configure(road_settings, traffic_settings, pickup_settings)
	world.crashed.connect(_end_run)
	world.notice.connect(hud.show_feedback)
	world.dashboard_changed.connect(hud.set_dashboard)
	_connect_scoring()
	hud.mode_requested.connect(set_easy_mode)
	hud.finish_requested.connect(finish_drive)
	hud.set_dashboard({"easy": easy_mode})
	_configure_collection_goal(easy_settings if easy_mode else null)
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
	hud.garage_action.connect(garage_action)
	hud.second_chance_chosen.connect(choose_second_chance)
	hud.share_requested.connect(ShareRules.open)
	_show_score()
	progress.load_progress()
	PreferenceRules.apply(progress, pickup_feedback, audio, hud)
	_apply_car()
	daily.load_state(progress.daily)
	achievements.load_state(progress.achievements)
	world.choose_weather(DailyTasks.today(), randf())
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


func set_easy_mode(enabled: bool) -> void:
	if state != RunState.START or not _focused:
		return
	easy_mode = enabled
	world.easy_settings = easy_settings if easy_mode else null
	world.reset_run(road_settings, traffic_settings, pickup_settings)
	_apply_car()
	world.choose_weather(DailyTasks.today(), randf())
	world.set_driving(false, false)
	hud.set_dashboard({"easy": easy_mode})
	_configure_collection_goal(easy_settings if easy_mode else null)


func finish_drive() -> void:
	if state != RunState.PAUSED or not _focused:
		return
	_end_kind = "finished"
	_finish_run()


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
	_take_boost()


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
	_take_boost()


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


## Every shop action (see GarageRules.apply): cars, paints, upgrades, routes, plates, and
## the market. Only between drives; purchases are checked by the rules.
func garage_action(action: String, id: String) -> void:
	if state == RunState.START and GarageRules.apply(action, id, garage, progress, car):
		_apply_car()


func _apply_car() -> void:
	car = GarageRules.current_car(garage, progress)
	assert(car != null, "Garage requires an available default car")
	var setup := GarageRules.drive_setup(garage, progress, car)
	world.set_car(setup.settings, car.texture, car.sprite_scale, setup.paint, setup.boosts)
	world.set_route(setup.route)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))


## A power-up won on the lucky wheel starts the drive (one write to clear it).
func _take_boost() -> void:
	if easy_mode:
		return
	var kind := WheelRules.take_boost(progress)
	if not kind.is_empty():
		world.start_power_up(kind)
		_on_power_up_collected(kind)
		hud.set_garage(garage, GarageRules.view(garage, progress, car))


func _reset_run() -> void:
	_reset_scoring()
	_revived = false
	world.reset_run(road_settings, traffic_settings, pickup_settings)
	world.choose_weather(DailyTasks.today(), randf())
	pickup_feedback.stop()


func _show_lists() -> void:
	hud.set_daily(daily.entries(), achievements.entries(), rivals.entries(progress.best_score))


func set_language(locale: String) -> void:
	progress.set_preferences(locale, progress.sound_enabled, progress.haptics_enabled)
	PreferenceRules.apply(progress, pickup_feedback, audio, hud)


func _set_option(enabled: bool, option: String) -> void:
	PreferenceRules.set_option(progress, option, enabled)
	PreferenceRules.apply(progress, pickup_feedback, audio, hud)


## Ends the drive: a crash ("car" or "sheep") or an empty tank ("fuel"). Far enough along,
## once per drive, with enough in the wallet, a second chance is offered first.
func _end_run(kind: String) -> void:
	if state != RunState.PLAYING:
		return
	world.set_driving(false)
	pickup_feedback.stop()
	audio.set_music_playing(false)
	_end_kind = kind
	if revival.can_offer(_revived, distance_metres, progress.wallet, score):
		state = RunState.SECOND_CHANCE
		var price := revival.price_for(score)
		hud.offer_second_chance(price, progress.wallet, revival.decide_seconds)
	else:
		_finish_run()


## The second-chance card: pay from the wallet and drive on, or see the results.
func choose_second_chance(accepted: bool) -> void:
	if state != RunState.SECOND_CHANCE:
		return
	if accepted and progress.spend(revival.price_for(score), func() -> void: pass):
		_revived = true
		state = RunState.PLAYING
		world.revive(revival.refuel_share, revival.grace_metres)
		hud.resume_run()
		hud.show_feedback("revived")
		audio.set_music_playing(true)
		return
	_finish_run()


func _finish_run() -> void:
	state = RunState.GAME_OVER
	var notes := som_collected + dollars_collected
	var run := DailyTasks.summary(notes, near_misses, distance_metres, score, refuels)
	var booked := RunRecords.finish(run, daily, achievements, progress, rivals)
	hud.set_best(progress.best_score, booked.new_best, progress.has_unsaved_changes)
	hud.set_garage(garage, GarageRules.view(garage, progress, car))
	_show_lists()
	hud.show_game_over(distance_metres, _end_kind, score, progress.wallet, booked)

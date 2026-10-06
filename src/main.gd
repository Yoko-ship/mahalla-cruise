class_name CruiseGame
extends Node2D
## Composes features and owns the shared driving clock. No drawing or raw input here.

enum RunState { START, PLAYING, PAUSED, GAME_OVER }

@export var road_settings: RoadSettings
@export var traffic_settings: TrafficSettings
@export var pickup_settings: PickupSettings

var state: RunState = RunState.START
var distance_metres: float = 0.0
var is_game_over: bool:
	get:
		return state == RunState.GAME_OVER
var score: int = 0
var som_collected: int = 0
var dollars_collected: int = 0
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


func _ready() -> void:
	assert(road_settings != null, "Main scene requires RoadSettings")
	assert(traffic_settings != null, "Main scene requires TrafficSettings")
	assert(pickup_settings != null, "Main scene requires PickupSettings")
	_start_position = player.position
	road.configure(road_settings)
	scenery.configure(road_settings)
	player.configure_bounds(road_settings.left_edge, road_settings.right_edge)
	traffic.configure(road_settings, traffic_settings)
	traffic.contacted.connect(_on_traffic_contacted)
	pickups.configure(road_settings, pickup_settings)
	pickups.collected.connect(_on_money_collected)
	hud.restart_requested.connect(restart_run)
	hud.play_requested.connect(start_run)
	hud.pause_requested.connect(pause_run)
	hud.resume_requested.connect(resume_run)
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.haptics_toggled.connect(_on_haptics_toggled)
	hud.set_feedback_options(pickup_feedback.sound_enabled, pickup_feedback.haptics_enabled)
	hud.set_distance(distance_metres)
	hud.set_score(score, som_collected, dollars_collected)
	progress.load_progress()
	hud.set_best(progress.best_score)
	player.set_driving_enabled(false)
	player.hide()
	hud.show_start(progress.best_score)


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


func pause_run() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.PAUSED
	player.set_driving_enabled(false)
	pickup_feedback.stop()
	hud.show_paused(score, distance_metres)


func resume_run() -> void:
	if state != RunState.PAUSED or not _focused:
		return
	state = RunState.PLAYING
	player.set_driving_enabled(true)
	hud.resume_run()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		pause_run()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if state != RunState.PLAYING:
		return
	hud.advance_hint(delta)
	var travel_pixels := road_settings.scroll_speed * delta
	distance_metres += travel_pixels / road_settings.pixels_per_metre
	road.advance(travel_pixels)
	scenery.advance(travel_pixels)
	traffic.set_distance(distance_metres)
	traffic.advance(travel_pixels, player.collision_bounds())
	# Crash takes priority; no money can be awarded on or after the crash frame.
	if not is_game_over:
		pickups.advance(
			travel_pixels,
			player.collision_bounds(),
			traffic.blocking_bounds(),
			traffic_settings.relative_speed
		)
	hud.set_distance(distance_metres)


func restart_run() -> void:
	if not is_game_over:
		return
	if not _focused:
		return
	state = RunState.PLAYING
	distance_metres = 0.0
	score = 0
	som_collected = 0
	dollars_collected = 0
	road.configure(road_settings)
	scenery.configure(road_settings)
	traffic.configure(road_settings, traffic_settings)
	pickups.configure(road_settings, pickup_settings)
	pickup_feedback.stop()
	player.reset_run(_start_position)
	hud.reset_run()
	hud.set_score(score, som_collected, dollars_collected)
	hud.set_best(progress.best_score, false, progress.has_unsaved_changes)


func _on_money_collected(points: int, note: BanknoteDefinition) -> void:
	if state != RunState.PLAYING:
		return
	score += points
	if note.is_dollar:
		dollars_collected += 1
	else:
		som_collected += 1
	hud.set_score(score, som_collected, dollars_collected)
	hud.show_pickup(points, note.display_name())
	pickup_feedback.play_pickup(note.is_dollar)


func _on_sound_toggled(enabled: bool) -> void:
	pickup_feedback.set_sound_enabled(enabled)
	hud.set_feedback_options(pickup_feedback.sound_enabled, pickup_feedback.haptics_enabled)


func _on_haptics_toggled(enabled: bool) -> void:
	pickup_feedback.set_haptics_enabled(enabled)
	hud.set_feedback_options(pickup_feedback.sound_enabled, pickup_feedback.haptics_enabled)


func _on_traffic_contacted() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.GAME_OVER
	player.set_driving_enabled(false)
	pickup_feedback.stop()
	var new_best := progress.record_score(score)
	hud.set_best(progress.best_score, new_best, progress.has_unsaved_changes)
	hud.show_game_over(distance_metres)

class_name DriveScoring
extends Node2D
## The drive in progress: run state, distance, and the counters that road events change
## (money, close calls, road points and events, refuels, power-ups). CruiseGame extends this
## with session flow, saved progress, and routing. No drawing, raw input, or road objects.

## SECOND_CHANCE: the drive has ended and the player is deciding whether to pay to drive on.
enum RunState { START, PLAYING, PAUSED, GAME_OVER, SECOND_CHANCE }

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
var _collection_settings: EasyDriveSettings

@onready var world: DriveWorld = $World
@onready var pickup_feedback: PickupFeedback = $PickupFeedback
@onready var hud: CruiseHUD = $HUD


func _connect_scoring() -> void:
	world.near_missed.connect(_on_near_missed)
	world.money_collected.connect(_on_money_collected)
	world.power_up_collected.connect(_on_power_up_collected)
	world.road_points.connect(_on_road_points)
	world.road_event.connect(_on_road_event)
	world.refueled.connect(_on_refueled)


func _reset_scoring() -> void:
	distance_metres = 0.0
	score = 0
	som_collected = 0
	dollars_collected = 0
	near_misses = 0
	refuels = 0
	_show_collection_goal(false, true)


func _on_money_collected(points: int, note: BanknoteDefinition) -> void:
	if state != RunState.PLAYING:
		return
	dollars_collected += int(note.is_dollar)
	som_collected += int(not note.is_dollar)
	var total := som_collected + dollars_collected
	var complete := (
		_collection_settings != null
		and total % maxi(1, _collection_settings.collection_target) == 0
	)
	var bonus := _collection_settings.collection_bonus if complete else 0
	_add_points(points + bonus)
	hud.show_pickup(points, note.display_name())
	pickup_feedback.play_pickup(note.is_dollar or complete)
	_show_collection_goal(complete)


func _configure_collection_goal(settings: EasyDriveSettings) -> void:
	_collection_settings = settings
	_show_collection_goal(false, true)


func _show_collection_goal(complete: bool = false, reset: bool = false) -> void:
	var goal: Dictionary = {}
	if _collection_settings != null:
		var target := maxi(1, _collection_settings.collection_target)
		goal = {
			"target": target,
			"collected": (som_collected + dollars_collected) % target,
			"bonus": _collection_settings.collection_bonus,
			"complete": complete,
			"reset": reset,
		}
	hud.set_dashboard({"collection": goal})


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


## Road points outside money: hazard and camera penalties, police rewards and fines.
func _on_road_points(points: int, text_key: String, sound: String) -> void:
	if state != RunState.PLAYING:
		return
	score = maxi(0, score + points)
	_show_score()
	hud.show_feedback(text_key, [absi(points)])
	pickup_feedback.play_event(sound)


## A road moment without points, such as a wedding convoy arriving.
func _on_road_event(text_key: String, sound: String) -> void:
	if state == RunState.PLAYING:
		hud.show_feedback(text_key)
		pickup_feedback.play_event(sound)


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

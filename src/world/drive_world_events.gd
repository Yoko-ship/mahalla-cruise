class_name DriveWorldEvents
extends Node2D
## The drive world's children and how their signals become world signals: notices, road
## points and events, money with the route and night bonuses, power-ups, refuels, and the
## per-frame dashboard, plus how they show on the street: point popups, a crash puff, and
## a brief shake of the whole street. DriveWorld extends this with configuring and advancing.

signal crashed(kind: String)
## A message for the road: a shield save, fuel, nightfall, cameras, police, and taxi
## orders (HUD text key and values).
signal notice(text_key: String, values: Array)
## Points already include double points and the night bonus.
signal near_missed(points: int, combo: int)
## Notes from the road, bus passengers, and taxi fares.
signal money_collected(points: int, note: BanknoteDefinition)
signal power_up_collected(kind: String)
## Points outside money: negative for hazards, camera and police fines, positive for a
## police check passed. text_key and sound are for the HUD and feedback.
signal road_points(points: int, text_key: String, sound: String)
signal refueled
## A road moment with its own sound: a wedding convoy ("wedding", "karnay").
signal road_event(text_key: String, sound: String)
## Dashboard values for the HUD, every frame: fuel, fuel_low, speed_kmh, limit_kmh (0 when
## no camera is ahead), ride_metres (-1 without a taxi passenger), and power_ups (see
## PowerUpEffects.view()).
signal dashboard_changed(view: Dictionary)

var _road_settings: RoadSettings
var _crashed: bool = false
var _speed_pixels: float = 0.0
var _fuel := {"fuel": 1.0, "fuel_low": false}
var _power_ups: Dictionary = {}
var _route: RouteDefinition
var _shake_seconds: float = 0.0
var _shake_total: float = 1.0
var _shake_strength: float = 0.0

@onready var road: RoadView = $Road
@onready var scenery: SceneryView = $Scenery
@onready var landmarks: LandmarkView = $Landmarks
@onready var cameras: SpeedCameraController = $Cameras
@onready var hazards: HazardController = $Hazards
@onready var fuel: FuelController = $Fuel
@onready var police: PoliceController = $Police
@onready var traffic: TrafficController = $Traffic
@onready var wedding: WeddingController = $Wedding
@onready var pickups: PickupController = $Pickups
@onready var taxi: TaxiController = $Taxi
@onready var player: PlayerCar = $PlayerCar
@onready var night: NightView = $Night
@onready var weather: WeatherView = $Weather
@onready var effects: RoadEffects = $Effects


func _connect_events() -> void:
	traffic.contacted.connect(_on_contacted)
	traffic.near_missed.connect(_on_near_missed)
	traffic.sheep_started.connect(notice.emit.bind("sheep_ahead", []))
	pickups.collected.connect(
		func(points: int, note: BanknoteDefinition) -> void:
			money_collected.emit(_pay(points), note)
	)
	pickups.collected_at.connect(
		func(spot: Vector2, points: int) -> void: effects.pop(spot, "+%d" % _pay(points))
	)
	pickups.power_up_collected.connect(power_up_collected.emit)
	pickups.power_ups_changed.connect(func(view: Dictionary) -> void: _power_ups = view)
	hazards.hit.connect(
		func(kind: String, penalty: int) -> void:
			_road_points(-penalty, "hazard_" + kind, "bump")
			shake(3.0, 0.2)
	)
	fuel.refueled.connect(refueled.emit)
	fuel.running_low.connect(notice.emit.bind("fuel_low", []))
	fuel.level_changed.connect(
		func(share: float, low: bool) -> void: _fuel = {"fuel": share, "fuel_low": low}
	)
	fuel.ran_out.connect(_on_out_of_fuel)
	night.fell.connect(func(percent: int) -> void: notice.emit("night_bonus", [percent]))
	cameras.warned.connect(func(limit: int) -> void: notice.emit("camera_ahead", [limit]))
	cameras.fined.connect(
		func(points: int) -> void: _road_points(-points, "hazard_camera", "camera")
	)
	cameras.passed_clean.connect(notice.emit.bind("camera_clean", []))
	taxi.called.connect(notice.emit.bind("taxi_call", []))
	taxi.boarded.connect(func(metres: int) -> void: notice.emit("taxi_aboard", [metres]))
	taxi.delivered.connect(_on_fare_paid)
	taxi.missed.connect(notice.emit.bind("taxi_missed", []))
	fuel.queue_ahead.connect(func(cars: int) -> void: notice.emit("fuel_queue", [cars]))
	fuel.partly_refueled.connect(func(percent: int) -> void: notice.emit("fuel_partial", [percent]))
	police.warned.connect(notice.emit.bind("police_ahead", []))
	police.cleared.connect(
		func(points: int) -> void: _road_points(_pay(points), "police_ok", "chime")
	)
	wedding.arrived.connect(road_event.emit.bind("wedding", "karnay"))
	wedding.tossed.connect(
		func(spot: Vector2, face_value: int) -> void: pickups.drop_note(spot, face_value)
	)
	police.fined.connect(func(points: int) -> void: _road_points(-points, "police_fine", "whistle"))


## Shakes the whole street by up to strength pixels, fading over seconds (real time).
func shake(strength: float, seconds: float) -> void:
	_shake_strength = maxf(_shake_strength * _shake_seconds / _shake_total, strength)
	_shake_total = maxf(0.01, seconds)
	_shake_seconds = _shake_total


func _process(delta: float) -> void:
	if _shake_seconds <= 0.0:
		return
	_shake_seconds = maxf(0.0, _shake_seconds - delta)
	var size := _shake_strength * _shake_seconds / _shake_total
	position = Vector2(randf_range(-size, size), randf_range(-size, size))


func _clear_effects() -> void:
	effects.clear()
	_shake_seconds = 0.0
	position = Vector2.ZERO


## Points outside money, shown as a popup above the car.
func _road_points(points: int, text_key: String, sound: String) -> void:
	var text := ("+%d" if points >= 0 else "−%d") % absi(points)
	var colour := RoadEffects.GAIN if points >= 0 else RoadEffects.LOSS
	effects.pop(player.position - Vector2(0, 56), text, colour)
	road_points.emit(points, text_key, sound)


func _emit_dashboard() -> void:
	var view := _fuel.duplicate()
	view.speed_kmh = speed_kmh() if _road_settings != null else 0
	var limits := [cameras.active_limit(), police.active_limit()].filter(
		func(x: int) -> bool: return x > 0
	)
	view.limit_kmh = limits.min() if not limits.is_empty() else 0
	view.ride_metres = taxi.ride_metres()
	view.power_ups = _power_ups
	dashboard_changed.emit(view)


func _on_near_missed(points: int, combo: int) -> void:
	var paid := _pay(points * pickups.point_multiplier())
	var text := "+%d" % paid if combo < 2 else "×%d  +%d" % [combo, paid]
	effects.pop(player.position - Vector2(0, 56), text, RoadEffects.CLOSE)
	near_missed.emit(paid, combo)


## Route bonus, then the night bonus.
func _pay(points: int) -> int:
	var scale := _route.points_scale if _route != null else 1.0
	return night.bonus(roundi(points * scale))


func _on_fare_paid(note: BanknoteDefinition, count: int, points: int) -> void:
	var total := 0
	for _note in range(count):
		var paid := _pay(points * pickups.point_multiplier())
		total += paid
		money_collected.emit(paid, note)
	notice.emit("taxi_paid", [total])


func speed_kmh() -> int:
	return _road_settings.kmh(_speed_pixels)


func _on_contacted() -> void:
	# A shield (or its short grace) knocks whatever was hit off the road instead.
	if pickups.absorb_crash():
		traffic.clear_contact()
		shake(3.0, 0.2)
		notice.emit("power_shield_used", [])
		return
	_crashed = true
	effects.puff(player.position - Vector2(0, 34))
	shake(7.0, 0.35)
	crashed.emit(traffic.last_contact_kind)


func _on_out_of_fuel() -> void:
	_crashed = true
	crashed.emit("fuel")

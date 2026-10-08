class_name DriveWorld
extends Node2D
## Everything on the street: road, scenery, city landmarks, speed cameras, hazards, fuel
## stations, police posts, traffic, pickups, taxi orders, the player car, and night. Main
## supplies settings, the car, the route, and the clock; the world turns the clock into
## travel (braking included) and signals road events up.

signal crashed(kind: String)
## A message for the road: a shield save, fuel, nightfall, cameras, police, and taxi
## orders (HUD text key and values).
signal notice(text_key: String, values: Array)
## Points already include double points and the night bonus.
signal near_missed(points: int, combo: int)
## Notes from the road, bus passengers, and taxi fares.
signal money_collected(points: int, note: BanknoteDefinition)
signal power_up_collected(kind: String)
signal power_ups_changed(view: Dictionary)
## Points outside money: negative for hazards, camera and police fines, positive for a
## police check passed. text_key and sound are for the HUD and feedback.
signal road_points(points: int, text_key: String, sound: String)
signal refueled
## Dashboard values for the HUD, every frame: fuel, fuel_low, speed_kmh, limit_kmh (0 when
## no camera is ahead), and ride_metres (-1 without a taxi passenger).
signal dashboard_changed(view: Dictionary)

var _road_settings: RoadSettings
var _traffic_settings: TrafficSettings
var _start_position: Vector2
var _crashed: bool = false
var _speed_pixels: float = 0.0
var _fuel := {"fuel": 1.0, "fuel_low": false}
var _route: RouteDefinition

@onready var road: RoadView = $Road
@onready var scenery: SceneryView = $Scenery
@onready var landmarks: LandmarkView = $Landmarks
@onready var cameras: SpeedCameraController = $Cameras
@onready var hazards: HazardController = $Hazards
@onready var fuel: FuelController = $Fuel
@onready var police: PoliceController = $Police
@onready var traffic: TrafficController = $Traffic
@onready var pickups: PickupController = $Pickups
@onready var taxi: TaxiController = $Taxi
@onready var player: PlayerCar = $PlayerCar
@onready var night: NightView = $Night


func _ready() -> void:
	_start_position = player.position
	traffic.contacted.connect(_on_contacted)
	traffic.near_missed.connect(_on_near_missed)
	pickups.collected.connect(
		func(points: int, note: BanknoteDefinition) -> void:
			money_collected.emit(_pay(points), note)
	)
	pickups.power_up_collected.connect(power_up_collected.emit)
	pickups.power_ups_changed.connect(power_ups_changed.emit)
	hazards.hit.connect(
		func(kind: String, penalty: int) -> void:
			road_points.emit(-penalty, "hazard_" + kind, "bump")
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
		func(points: int) -> void: road_points.emit(-points, "hazard_camera", "camera")
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
		func(points: int) -> void: road_points.emit(_pay(points), "police_ok", "chime")
	)
	police.fined.connect(
		func(points: int) -> void: road_points.emit(-points, "police_fine", "whistle")
	)


## Clears the street for a new drive with these settings; the player keeps its place.
func configure(route: RoadSettings, cars: TrafficSettings, money: PickupSettings) -> void:
	_road_settings = route
	_traffic_settings = cars
	_crashed = false
	road.configure(route)
	scenery.configure(route)
	landmarks.configure(route, _route.landmarks if _route != null else "")
	traffic.configure(route, cars)
	pickups.configure(route, money)
	hazards.configure(route)
	fuel.configure(route)
	police.configure(route)
	night.configure(route)
	cameras.configure(route)
	taxi.configure(route, money)
	if player.settings != null:
		_speed_pixels = route.scroll_speed * player.settings.travel_speed_scale
	_emit_dashboard()


func reset_run(route: RoadSettings, cars: TrafficSettings, money: PickupSettings) -> void:
	configure(route, cars, money)
	player.reset_run(_start_position)


## boosts come from UpgradeRules.boosts(): tank and suspension multipliers.
func set_car(
	settings: CarSettings, texture: Texture2D, sprite_scale: float, paint: Color, boosts: Dictionary
) -> void:
	player.apply_car(settings, texture, sprite_scale, paint)
	player.configure_bounds(_road_settings.left_edge, _road_settings.right_edge)
	fuel.set_capacity_scale(boosts.get("tank", 1.0))
	hazards.penalty_scale = boosts.get("suspension", 1.0)
	taxi.tip_notes = boosts.get("tips", 0)
	player.set_plate(boosts.get("plate", ""))
	_speed_pixels = _road_settings.scroll_speed * settings.travel_speed_scale
	_emit_dashboard()


func set_driving(enabled: bool, shown: bool = true) -> void:
	if enabled:
		_crashed = false
	player.visible = shown
	player.set_driving_enabled(enabled)


## The city: street tint, sidewalk landmarks, and the points bonus. Between drives.
func set_route(route: RouteDefinition) -> void:
	_route = route
	scenery.modulate = route.tint
	landmarks.configure(_road_settings, route.landmarks)


## The HUD brake pedal; the player also reads the Down key itself.
func set_braking(held: bool) -> void:
	player.set_braking(held)


## Advances the car's speed (braking or recovering) by delta and returns this frame's travel.
func travel_pixels(delta: float) -> float:
	var share := player.update_speed(delta)
	_speed_pixels = _road_settings.scroll_speed * player.settings.travel_speed_scale * share
	return _speed_pixels * delta


func speed_kmh() -> int:
	return _road_settings.kmh(_speed_pixels)


func set_view(bounds: Rect2, vertical_padding: float) -> void:
	road.set_view_bounds(bounds)
	scenery.set_view_bounds(bounds)
	landmarks.set_view_bounds(bounds)
	night.set_view_bounds(bounds)
	traffic.set_vertical_padding(vertical_padding)
	pickups.set_vertical_padding(vertical_padding)
	hazards.set_vertical_padding(vertical_padding)
	fuel.set_vertical_padding(vertical_padding)
	police.set_vertical_padding(vertical_padding)
	cameras.set_vertical_padding(vertical_padding)
	taxi.set_vertical_padding(vertical_padding)


func advance(travel_pixels: float, metres: float) -> void:
	road.advance(travel_pixels)
	scenery.advance(travel_pixels)
	landmarks.advance(travel_pixels)
	traffic.set_distance(metres)
	var player_bounds := player.collision_bounds()
	var hazard_bounds := hazards.item_bounds()
	var avoid_for_sheep := pickups.item_bounds()
	avoid_for_sheep.append_array(hazard_bounds)
	traffic.advance(travel_pixels, player_bounds, avoid_for_sheep, hazard_bounds)
	# Crash takes priority; no money can be awarded on or after the crash frame.
	if _crashed:
		return
	var speed := _traffic_settings.relative_speed
	var blocking := traffic.blocking_bounds()
	var money_obstacles := blocking.duplicate()
	money_obstacles.append_array(hazard_bounds)
	pickups.hold_stops = taxi.is_busy()
	pickups.advance(travel_pixels, player_bounds, money_obstacles, speed)
	taxi.advance(travel_pixels, player_bounds, pickups.bus_stops.is_empty())
	var items := pickups.item_bounds()
	for power_up in pickups.power_ups:
		items.append(power_up.collection_bounds())
	hazards.advance(travel_pixels, player_bounds, blocking, items, speed)
	# Fuel and police share the left curb, as bus stops and taxi orders share the right.
	fuel.hold_stations = police.is_busy()
	fuel.advance(travel_pixels, player_bounds, travel_pixels / maxf(_speed_pixels, 1.0))
	police.advance(travel_pixels, player_bounds, speed_kmh(), fuel.stations.is_empty())
	cameras.advance(travel_pixels, player.position.y, speed_kmh())
	night.advance(travel_pixels, metres, player.position)
	_emit_dashboard()


func _emit_dashboard() -> void:
	var view := _fuel.duplicate()
	view.speed_kmh = speed_kmh() if _road_settings != null else 0
	var limits := [cameras.active_limit(), police.active_limit()].filter(
		func(x: int) -> bool: return x > 0
	)
	view.limit_kmh = limits.min() if not limits.is_empty() else 0
	view.ride_metres = taxi.ride_metres()
	dashboard_changed.emit(view)


func _on_contacted() -> void:
	# A shield (or its short grace) knocks whatever was hit off the road instead.
	if pickups.absorb_crash():
		traffic.clear_contact()
		notice.emit("power_shield_used", [])
		return
	_crashed = true
	crashed.emit(traffic.last_contact_kind)


func _on_near_missed(points: int, combo: int) -> void:
	near_missed.emit(_pay(points * pickups.point_multiplier()), combo)


## Route bonus, then the night bonus.
func _pay(points: int) -> int:
	var scale := _route.points_scale if _route != null else 1.0
	return night.bonus(roundi(points * scale))


func _on_out_of_fuel() -> void:
	_crashed = true
	crashed.emit("fuel")


func _on_fare_paid(note: BanknoteDefinition, count: int, points: int) -> void:
	var total := 0
	for _note in range(count):
		var paid := _pay(points * pickups.point_multiplier())
		total += paid
		money_collected.emit(paid, note)
	notice.emit("taxi_paid", [total])

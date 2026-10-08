class_name DriveWorld
extends Node2D
## Everything on the street: road, scenery, hazards, fuel stations, traffic, pickups, the
## player car, and night. Main supplies settings, the car, and travel; road events signal up.

signal crashed(kind: String)
## A message for the road: a shield save, low fuel, or nightfall (HUD text key and values).
signal notice(text_key: String, values: Array)
## Points already include double points and the night bonus.
signal near_missed(points: int, combo: int)
signal money_collected(points: int, note: BanknoteDefinition)
signal power_up_collected(kind: String)
signal power_ups_changed(view: Dictionary)
signal hazard_hit(kind: String, penalty: int)
signal refueled
signal fuel_changed(share: float, low: bool)

var _road_settings: RoadSettings
var _traffic_settings: TrafficSettings
var _start_position: Vector2
var _crashed: bool = false

@onready var road: RoadView = $Road
@onready var scenery: SceneryView = $Scenery
@onready var hazards: HazardController = $Hazards
@onready var fuel: FuelController = $Fuel
@onready var traffic: TrafficController = $Traffic
@onready var pickups: PickupController = $Pickups
@onready var player: PlayerCar = $PlayerCar
@onready var night: NightView = $Night


func _ready() -> void:
	_start_position = player.position
	traffic.contacted.connect(_on_contacted)
	traffic.near_missed.connect(_on_near_missed)
	pickups.collected.connect(
		func(points: int, note: BanknoteDefinition) -> void:
			money_collected.emit(night.bonus(points), note)
	)
	pickups.power_up_collected.connect(power_up_collected.emit)
	pickups.power_ups_changed.connect(power_ups_changed.emit)
	hazards.hit.connect(hazard_hit.emit)
	fuel.refueled.connect(refueled.emit)
	fuel.running_low.connect(notice.emit.bind("fuel_low", []))
	fuel.level_changed.connect(fuel_changed.emit)
	fuel.ran_out.connect(_on_out_of_fuel)
	night.fell.connect(func(percent: int) -> void: notice.emit("night_bonus", [percent]))


## Clears the street for a new drive with these settings; the player keeps its place.
func configure(route: RoadSettings, cars: TrafficSettings, money: PickupSettings) -> void:
	_road_settings = route
	_traffic_settings = cars
	_crashed = false
	road.configure(route)
	scenery.configure(route)
	traffic.configure(route, cars)
	pickups.configure(route, money)
	hazards.configure(route)
	fuel.configure(route)
	night.configure(route)


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


func set_driving(enabled: bool, shown: bool = true) -> void:
	if enabled:
		_crashed = false
	player.visible = shown
	player.set_driving_enabled(enabled)


func set_view(bounds: Rect2, vertical_padding: float) -> void:
	road.set_view_bounds(bounds)
	scenery.set_view_bounds(bounds)
	night.set_view_bounds(bounds)
	traffic.set_vertical_padding(vertical_padding)
	pickups.set_vertical_padding(vertical_padding)
	hazards.set_vertical_padding(vertical_padding)
	fuel.set_vertical_padding(vertical_padding)


func advance(travel_pixels: float, metres: float) -> void:
	road.advance(travel_pixels)
	scenery.advance(travel_pixels)
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
	pickups.advance(travel_pixels, player_bounds, money_obstacles, speed)
	var items := pickups.item_bounds()
	for power_up in pickups.power_ups:
		items.append(power_up.collection_bounds())
	hazards.advance(travel_pixels, player_bounds, blocking, items, speed)
	fuel.advance(travel_pixels, player_bounds)
	night.advance(travel_pixels, metres, player.position)


func _on_contacted() -> void:
	# A shield (or its short grace) knocks whatever was hit off the road instead.
	if pickups.absorb_crash():
		traffic.clear_contact()
		notice.emit("power_shield_used", [])
		return
	_crashed = true
	crashed.emit(traffic.last_contact_kind)


func _on_near_missed(points: int, combo: int) -> void:
	near_missed.emit(night.bonus(points * pickups.point_multiplier()), combo)


func _on_out_of_fuel() -> void:
	_crashed = true
	crashed.emit("fuel")

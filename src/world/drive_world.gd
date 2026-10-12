class_name DriveWorld
extends DriveWorldEvents
## Everything on the street: road, scenery, city landmarks, speed cameras, hazards, fuel
## stations, police posts, traffic, wedding convoys, pickups, taxi orders, the player car,
## night, the weather, and short effects. Main supplies settings, the car, the route, and
## the clock; the world turns the clock into travel (braking included) and signals road
## events up (see DriveWorldEvents).

var _traffic_settings: TrafficSettings
var _start_position: Vector2


func _ready() -> void:
	_start_position = player.position
	_connect_events()


## Clears the street for a new drive with these settings; the player keeps its place.
func configure(route: RoadSettings, cars: TrafficSettings, money: PickupSettings) -> void:
	_road_settings = route
	_traffic_settings = cars
	_crashed = false
	_clear_effects()
	road.configure(route)
	scenery.configure(route)
	landmarks.configure(route, _route.landmarks if _route != null else "")
	traffic.configure(route, cars)
	wedding.configure(route)
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


## Second chance: whatever was hit leaves the road, an empty tank gets refuel_share, and
## further contact is absorbed for grace_metres. Driving resumes.
func revive(refuel_share: float, grace_metres: float) -> void:
	traffic.clear_contact()
	fuel.top_up(refuel_share)
	pickups.grant_grace(grace_metres)
	set_driving(true)
	_emit_dashboard()


## Weather for day (see WeatherRules.pick); it only changes the look of the street.
func choose_weather(day: String, roll: float) -> void:
	weather.set_weather(WeatherRules.pick(weather.settings, day, roll))


## A lucky-wheel power-up for the drive that is starting.
func start_power_up(kind: String) -> void:
	pickups.activate(kind)
	_emit_dashboard()


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


func set_view(bounds: Rect2, vertical_padding: float) -> void:
	road.set_view_bounds(bounds)
	scenery.set_view_bounds(bounds)
	landmarks.set_view_bounds(bounds)
	night.set_view_bounds(bounds)
	weather.set_view_bounds(bounds)
	traffic.set_vertical_padding(vertical_padding)
	wedding.set_vertical_padding(vertical_padding)
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
	traffic.hold_spawns = wedding.wants_road()
	traffic.advance(travel_pixels, player_bounds, avoid_for_sheep, hazard_bounds)
	# Crash takes priority; no money can be awarded on or after the crash frame.
	if _crashed:
		return
	var speed := _traffic_settings.relative_speed
	var landing := hazard_bounds.duplicate()
	for power_up in pickups.power_ups:
		landing.append(power_up.collection_bounds())
	wedding.advance(travel_pixels, traffic.is_clear(), landing)
	var blocking := traffic.blocking_bounds()
	blocking.append_array(wedding.blocking_bounds())
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
	weather.advance(travel_pixels)
	_emit_dashboard()

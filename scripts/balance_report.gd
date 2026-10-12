extends SceneTree
## Automated balance playtest: a simple bot drives the real game many times and reports how
## drives play out (distance, points, causes, road events, wallet growth). It steers like a
## careful player: away from cars, sheep, and road works, towards money, and (above all
## but safety) to a METAN bay once the tank is below 55%. It accepts every second chance it can afford. Memory-only save.
## Two profiles: "skilled" (re-plans every frame, sees far, steers fully) and "casual"
## (re-plans every 0.4 s, sees less, steers at 60%), as rough bounds for real players.
## Usage: ./scripts/godot.sh --headless --path . --script scripts/balance_report.gd
## [-- drives [skilled|casual]]

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const STEP: float = 1.0 / 30.0
const MAX_METRES: float = 6000.0
const PROFILES := {
	"skilled": {"replan_frames": 1, "look_ahead": 330.0, "steering": 1.0},
	"casual": {"replan_frames": 12, "look_ahead": 230.0, "steering": 0.6},
}

var _game: CruiseGame
var _weddings: int = 0
var _sochqi: int = 0
var _revives: int = 0
var _profile: Dictionary = PROFILES.skilled
var _profile_name: String = "skilled"
var _target_x: float = 216.0
var _frame: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var drives := 30
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		drives = maxi(1, args[0].to_int())
	if args.size() > 1 and PROFILES.has(args[1]):
		_profile_name = args[1]
		_profile = PROFILES[_profile_name]
	_game = MAIN_SCENE.instantiate() as CruiseGame
	(_game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(_game)
	_game.set_process(false)
	_game.set_language("en")
	_game.world.wedding.arrived.connect(func() -> void: _weddings += 1)
	_game.world.wedding.tossed.connect(func(_spot: Vector2, _value: int) -> void: _sochqi += 1)
	var results: Array[Dictionary] = []
	for drive in range(drives):
		results.append(_drive())
	_report(results)
	_game.free()
	quit(0)


func _drive() -> Dictionary:
	if _game.state == CruiseGame.RunState.START:
		_game.start_run()
	else:
		_game.restart_run()
	_game.world.player.set_physics_process(false)
	var weddings := _weddings
	var revived := false
	var frames := 0
	while _game.distance_metres < MAX_METRES:
		_steer()
		_game.advance(STEP)
		frames += 1
		if _game.state == CruiseGame.RunState.SECOND_CHANCE:
			revived = true
			_revives += 1
			_game.choose_second_chance(true)
		if _game.is_game_over:
			break
	var cause := _game.hud.game_over_panel._crash_kind if _game.is_game_over else "cap"
	if not _game.is_game_over:
		# End a capped drive for real: a shield or grace would absorb the contact.
		_game.world.pickups.effects.shield = false
		_game.world.pickups.effects.grace_metres = 0.0
		_game.world.traffic.contacted.emit()
		_game.choose_second_chance(false)
	return {
		"metres": _game.distance_metres,
		"score": _game.score,
		"notes": _game.som_collected + _game.dollars_collected,
		"close": _game.near_misses,
		"refuels": _game.refuels,
		"cause": cause,
		"weddings": _weddings - weddings,
		"revived": revived,
		"wallet": _game.progress.wallet,
		"minutes": frames * STEP / 60.0,
	}


## Picks the safest lane ahead (money and the METAN bay add appeal) and steers towards it
## at the car's steering speed.
func _steer() -> void:
	var world := _game.world
	var player := world.player
	_frame += 1
	if _frame % int(_profile.replan_frames) == 0:
		_target_x = _plan()
	var reach := player.settings.steering_speed * float(_profile.steering) * STEP
	player.position.x = move_toward(player.position.x, _target_x, reach)


func _plan() -> float:
	var world := _game.world
	var player := world.player
	var look_ahead: float = _profile.look_ahead
	var y := player.position.y
	var best_x := player.position.x
	var best := -INF
	var candidates: Array[float] = []
	for step in range(9):
		candidates.append(lerpf(player.left_limit, player.right_limit, step / 8.0))
	var obstacles: Array[Rect2] = []
	for car in world.traffic.vehicles:
		obstacles.append(car.collision_bounds())
	obstacles.append_array(world.traffic.sheep_crossing.blocking_bounds())
	for hazard in world.hazards.hazards:
		if hazard.kind == "works":
			obstacles.append(hazard.collision_bounds())
	var low_fuel := world.fuel.share() < 0.55
	for x in candidates:
		var value := -absf(x - player.position.x) * 0.02
		for obstacle in obstacles:
			# Anything level with the car or up to look_ahead above it; nearer is worse.
			var bounds := player.collision_bounds()
			var ahead := bounds.position.y - obstacle.end.y
			if obstacle.position.y < bounds.end.y + 10.0 and ahead < look_ahead:
				var gap := maxf(obstacle.position.x - x, x - obstacle.end.x) - bounds.size.x * 0.5
				if gap < 10.0:
					value -= 1000.0 * (1.0 - maxf(0.0, ahead) / look_ahead) + 200.0
		for note in world.pickups.items:
			var ahead := y - note.position.y
			if ahead > 0.0 and ahead < 400.0 and absf(note.position.x - x) < 30.0:
				value += 8.0 * note.points / maxf(1.0, ahead / 100.0) + 4.0
		if low_fuel and not world.fuel.stations.is_empty():
			value += (
				900.0
				* (
					1.0
					- (x - player.left_limit) / maxf(1.0, player.right_limit - player.left_limit)
				)
			)
		if value > best:
			best = value
			best_x = x
	return best_x


func _report(results: Array[Dictionary]) -> void:
	var metres: Array[float] = []
	var scores: Array[float] = []
	var causes := {}
	var weddings := 0
	var revived := 0
	var minutes := 0.0
	var refuels := 0
	for result in results:
		refuels += result.refuels
		metres.append(result.metres)
		scores.append(result.score)
		causes[result.cause] = causes.get(result.cause, 0) + 1
		weddings += result.weddings
		revived += int(result.revived)
		minutes += result.minutes
	metres.sort()
	scores.sort()
	var count := results.size()
	print(
		(
			"BALANCE REPORT (%s): %d bot drives with the %s"
			% [_profile_name, count, _game.car.display_name]
		)
	)
	print(
		(
			"  distance m: median %d, p25 %d, p75 %d, max %d"
			% [metres[count / 2], metres[count / 4], metres[count * 3 / 4], metres.back()]
		)
	)
	print(
		(
			"  points: median %d, p25 %d, p75 %d, max %d"
			% [scores[count / 2], scores[count / 4], scores[count * 3 / 4], scores.back()]
		)
	)
	print("  minutes per drive: %.1f average" % (minutes / count))
	print("  ended by: %s; refuels %.1f per drive" % [str(causes), float(refuels) / count])
	print(
		(
			"  wedding convoys: %d (%.2f per drive), sochqi notes thrown: %d"
			% [weddings, float(weddings) / count, _sochqi]
		)
	)
	print("  second chances taken: %d of %d drives" % [revived, count])
	print(
		(
			"  wallet after all drives: %d (rivals passed: best %d, place %d)"
			% [
				_game.progress.wallet,
				_game.progress.best_score,
				_game.rivals.rank(_game.progress.best_score)
			]
		)
	)
	for car in _game.garage.cars:
		var drives_needed := ceili(car.price / maxf(1.0, _game.progress.wallet / float(count)))
		print("  %s (%d): about %d drives of income" % [car.display_name, car.price, drives_needed])

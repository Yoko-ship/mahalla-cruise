extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const WEATHER: WeatherSettings = preload("res://src/weather/default_weather.tres")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_holidays()
	_test_seasons()
	_test_view()
	_test_game()
	await create_timer(0.4).timeout
	if failures == 0:
		print("PASS: seasons, holidays, weather particles, and greetings (%d checks)" % checks)
	quit(1 if failures else 0)


func _test_holidays() -> void:
	_check(WeatherRules.holiday("2026-03-21") == "navruz", "Navruz on 21 March")
	_check(WeatherRules.holiday("2026-03-14") == "navruz", "The Navruz week starts on the 14th")
	_check(WeatherRules.holiday("2026-03-29") == "", "Navruz is over on the 29th")
	_check(WeatherRules.holiday("2026-09-01") == "independence", "Independence Day")
	_check(WeatherRules.holiday("2026-08-30") == "independence", "Its eve")
	_check(WeatherRules.holiday("2026-12-31") == "new_year", "New Year's Eve")
	_check(WeatherRules.holiday("2027-01-07") == "new_year", "Until 7 January")
	_check(WeatherRules.holiday("2026-10-12") == "", "An ordinary day")


func _test_seasons() -> void:
	_check(WeatherRules.pick(WEATHER, "2026-03-21", 0.99) == "blossom", "Navruz blossom")
	_check(WeatherRules.pick(WEATHER, "2026-09-01", 0.0) == "confetti", "Independence confetti")
	_check(WeatherRules.pick(WEATHER, "2027-01-01", 0.99) == "snow", "New Year always snows")
	_check(WeatherRules.pick(WEATHER, "2027-02-10", 0.1) == "snow", "Winter snow")
	_check(WeatherRules.pick(WEATHER, "2027-02-10", 0.9) == "clear", "Some winter days are clear")
	_check(WeatherRules.pick(WEATHER, "2027-04-10", 0.1) == "rain", "Spring showers")
	_check(WeatherRules.pick(WEATHER, "2027-04-10", 0.5) == "clear", "Mostly clear spring")
	_check(WeatherRules.pick(WEATHER, "2027-07-10", 0.0) == "clear", "Summer stays clear")
	_check(WeatherRules.pick(WEATHER, "2026-10-12", 0.1) == "rain", "Autumn rain")
	_check(WeatherRules.pick(WEATHER, "2026-10-12", 0.5) == "leaves", "Autumn leaves")
	_check(WeatherRules.pick(WEATHER, "2026-10-12", 0.9) == "clear", "Clear autumn days")


func _test_view() -> void:
	var view := (load("res://src/weather/weather_view.tscn") as PackedScene).instantiate()
	var weather := view as WeatherView
	root.add_child(weather)
	weather.set_view_bounds(Rect2(-50, -100, 532, 968))
	weather.set_weather("snow")
	_check(weather.visible and weather.particles.size() == WEATHER.counts.snow, "Snow falls")
	var bounds := Rect2(-50, -100, 532, 968)
	_check(_inside(weather, bounds, 0.0, 0.0), "Flakes start inside the view")
	var before := weather.particles[0].y
	weather._process(0.1)
	_check(weather.particles[0].y != before, "Flakes fall in real time")
	before = weather.particles[0].y
	weather.advance(10.0)
	_check(
		weather.particles[0].y > before or weather.particles[0].y < bounds.position.y + 40.0,
		"Travel carries them down"
	)
	for _frame in range(400):
		weather._process(0.1)
	_check(_inside(weather, bounds, 40.0, 20.0), "Fallen flakes wrap back to the top")
	weather.set_weather("clear")
	_check(not weather.visible and weather.particles.is_empty(), "Clear weather draws nothing")
	for kind in ["rain", "leaves", "blossom", "confetti"]:
		weather.set_weather(kind)
		weather._process(0.1)
		_check(weather.particles.size() == WEATHER.counts[kind], "Particles for " + kind)
	weather.free()


func _test_game() -> void:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = ""
	root.add_child(game)
	game.set_process(false)
	game.set_language("en")
	var expected := WeatherRules.pick(WEATHER, DailyTasks.today(), 0.0)
	var possible := [expected, WeatherRules.pick(WEATHER, DailyTasks.today(), 0.999)]
	possible.append(WeatherRules.pick(WEATHER, DailyTasks.today(), 0.5))
	_check(game.world.weather.kind in possible, "Today's weather from the season")
	_check(game.world.weather.z_index > game.world.night.z_index, "Weather falls over the night")
	game.world.choose_weather("2027-02-10", 0.1)
	_check(game.world.weather.kind == "snow", "The world shows the chosen weather")
	var view := GarageRules.view(game.garage, game.progress, game.car, "2026-03-21")
	game.hud.set_garage(game.garage, view)
	_check(game.hud.menu.subtitle.text == "Happy Navruz!", "The start card greets on Navruz")
	game.set_language("ru")
	_check(game.hud.menu.subtitle.text == "С праздником Навруз!", "In Russian too")
	view = GarageRules.view(game.garage, game.progress, game.car, "2026-10-12")
	game.hud.set_garage(game.garage, view)
	game.set_language("en")
	_check(game.hud.menu.subtitle.text == "A little drive. A familiar place.", "Ordinary tagline")
	game.start_run()
	game.world.player.set_physics_process(false)
	game.world.choose_weather("2026-10-12", 0.1)
	var before := game.score
	for _frame in range(30):
		game.advance(1.0 / 30.0)
	_check(game.score == before, "Rain changes no points")
	game.free()


## Every particle's height lies within bounds, allowing above and below pixels outside.
func _inside(weather: WeatherView, bounds: Rect2, above: float, below: float) -> bool:
	for particle in weather.particles:
		if particle.y < bounds.position.y - above or particle.y > bounds.end.y + below:
			return false
	return true


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

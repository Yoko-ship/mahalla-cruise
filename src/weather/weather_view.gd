class_name WeatherView
extends Node2D
## Draws the weather over the street (z 4): rain streaks with a grey tint, snowflakes,
## tumbling leaves or blossom petals, or confetti in the flag's colours. Particles fall in
## real time, so menus keep their weather, and road travel carries them down a little more.

const RAIN := Color(0.82, 0.88, 0.97, 0.45)
const RAIN_TINT := Color(0.32, 0.4, 0.5, 0.18)
const SNOW := Color(1, 1, 1, 0.88)
const SNOW_TINT := Color(0.86, 0.91, 1, 0.1)
const LEAVES: Array[Color] = [Color("d9822b"), Color("e3b23c"), Color("a5502a"), Color("c96a1b")]
const BLOSSOM: Array[Color] = [Color("f7c6d9"), Color("ffffff"), Color("f29bbd")]
const FLAG: Array[Color] = [Color("0099b5"), Color("ffffff"), Color("1eb53a"), Color("ce1126")]

@export var settings: WeatherSettings

var kind: String = "clear"
## x, y, and a per-particle random value in z.
var particles: PackedVector3Array = PackedVector3Array()
var _bounds := Rect2(0, 0, 432, 768)
var _time: float = 0.0
var _random := RandomNumberGenerator.new()


func set_view_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_scatter()


func set_weather(next: String) -> void:
	kind = next
	_scatter()


func advance(travel_pixels: float) -> void:
	_fall(travel_pixels * settings.travel_drift)


func _process(delta: float) -> void:
	if particles.is_empty():
		return
	_time += delta
	_fall(delta * _speed())


func _speed() -> float:
	return {"rain": 720.0, "snow": 55.0, "confetti": 85.0}.get(kind, 60.0)


## Moves every particle down by pixels (scaled by its own speed) and wraps it to the top.
func _fall(pixels: float) -> void:
	for index in range(particles.size()):
		var particle := particles[index]
		particle.y += pixels * (0.7 + 0.6 * particle.z)
		if kind == "rain":
			particle.x -= pixels * 0.15
		if particle.y > _bounds.end.y + 20.0:
			particle.y -= _bounds.size.y + 40.0
			particle.x = _random.randf_range(_bounds.position.x, _bounds.end.x)
		if particle.x < _bounds.position.x - 20.0:
			particle.x += _bounds.size.x + 40.0
		particles[index] = particle
	queue_redraw()


func _scatter() -> void:
	particles.clear()
	var count: int = settings.counts.get(kind, 0) if settings != null else 0
	for _index in range(count):
		particles.append(
			Vector3(
				_random.randf_range(_bounds.position.x, _bounds.end.x),
				_random.randf_range(_bounds.position.y, _bounds.end.y),
				_random.randf()
			)
		)
	visible = count > 0
	queue_redraw()


func _draw() -> void:
	match kind:
		"rain":
			draw_rect(_bounds, RAIN_TINT)
			for particle in particles:
				var top := Vector2(particle.x, particle.y)
				var length := 14.0 + 9.0 * particle.z
				draw_line(top, top + Vector2(-0.15, 1.0) * length, RAIN, 1.2)
		"snow":
			draw_rect(_bounds, SNOW_TINT)
			for particle in particles:
				var sway := 9.0 * sin(_time * 1.3 + particle.z * TAU)
				draw_circle(Vector2(particle.x + sway, particle.y), 1.6 + 2.0 * particle.z, SNOW)
		"leaves", "blossom":
			var colours := LEAVES if kind == "leaves" else BLOSSOM
			var size := Vector2(7.0, 3.3) if kind == "leaves" else Vector2(4.2, 2.6)
			for particle in particles:
				var sway := 18.0 * sin(_time * 1.1 + particle.z * TAU)
				var turn := _time * (1.5 + particle.z * 2.0) + particle.z * TAU
				var colour := colours[int(particle.z * 97.0) % colours.size()]
				_draw_petal(Vector2(particle.x + sway, particle.y), turn, size, colour)
		"confetti":
			for particle in particles:
				var turn := _time * (2.0 + particle.z * 3.0) + particle.z * TAU
				var colour := FLAG[int(particle.z * 97.0) % FLAG.size()]
				var squash := absf(cos(turn))
				draw_set_transform(Vector2(particle.x, particle.y), turn * 0.3)
				draw_rect(Rect2(-3.0, -2.0 * squash, 6.0, 4.0 * squash), colour)
				draw_set_transform(Vector2.ZERO)


func _draw_petal(spot: Vector2, turn: float, size: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for step in range(8):
		var around := TAU * step / 8.0
		points.append(spot + Vector2(cos(around) * size.x, sin(around) * size.y).rotated(turn))
	draw_colored_polygon(points, colour)

class_name DriveOverlay
extends Control
## Values over the road while driving: distance, points, record, pause, horn, brake pedal,
## power-ups, fuel, speed, taxi ride, feedback popups, and the first-drive hint. Display
## only; buttons and the pedal signal upward.

signal pause_pressed
signal horn_pressed
signal brake_changed(held: bool)

var _hint_remaining: float = 0.0
var _metres: float = 0.0
var _points: int = 0
var _best: int = 0
var _playfield_offset := Vector2.ZERO

@onready var title: Label = $Title
@onready var distance_label: Label = $Distance
@onready var score_label: Label = $Score
@onready var best_label: Label = $Best
@onready var pause_button: Button = $Pause
@onready var horn_button: Button = $Horn
@onready var power_up_bar: PowerUpBar = $PowerUps
@onready var fuel_gauge: FuelGauge = $Fuel
@onready var ride_chip: RideChip = $Ride
@onready var speedometer: Speedometer = $Speed
@onready var brake_pedal: BrakePedal = $Brake
@onready var pickup_label: FeedbackPopup = $PickupFeedback
@onready var controls_label: Label = $Controls


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	horn_button.pressed.connect(func() -> void: horn_pressed.emit())
	brake_pedal.held_changed.connect(brake_changed.emit)


## Every child follows the playfield; the overlay itself fills the screen.
func set_playfield_offset(offset: Vector2) -> void:
	var shift := offset - _playfield_offset
	for control: Control in get_children():
		control.position += shift
	pickup_label.base_y += shift.y
	_playfield_offset = offset


func set_active(active: bool) -> void:
	for control: Control in [
		title,
		distance_label,
		score_label,
		best_label,
		pause_button,
		horn_button,
		power_up_bar,
		fuel_gauge,
		ride_chip,
		speedometer,
		brake_pedal
	]:
		control.visible = active
	controls_label.visible = active and _hint_remaining > 0.0


func start_hint(seconds: float) -> void:
	_hint_remaining = seconds
	controls_label.text = tr("hint").replace("\\n", "\n")
	controls_label.visible = _hint_remaining > 0.0 and distance_label.visible


## delta advances the first-drive hint; it is passed only while driving.
func set_distance(metres: float, delta: float = 0.0) -> void:
	if delta > 0.0:
		_hint_remaining = maxf(0.0, _hint_remaining - delta)
		controls_label.visible = _hint_remaining > 0.0
	_metres = metres
	var text := tr("distance") % int(metres)
	if distance_label.text != text:
		distance_label.text = text
		_fit_value(distance_label, 21, 89.0)


func set_score(points: int) -> void:
	_points = points
	score_label.text = tr("points_short") % points
	_fit_value(score_label, 19, 116.0)


func set_best(points: int) -> void:
	_best = points
	best_label.text = tr("best") % points
	_fit_value(best_label, 15, 144.0)


func show_text(message: String) -> void:
	pickup_label.play(message)


func dismiss_text() -> void:
	pickup_label.dismiss()


func set_power_ups(view: Dictionary) -> void:
	power_up_bar.set_view(view)


## view: fuel, fuel_low, speed_kmh, limit_kmh, and ride_metres (see DriveWorld).
func set_dashboard(view: Dictionary) -> void:
	fuel_gauge.set_level(view.get("fuel", 1.0), view.get("fuel_low", false))
	speedometer.set_speed(view.get("speed_kmh", 0), view.get("limit_kmh", 0))
	ride_chip.set_metres(view.get("ride_metres", -1))


func refresh_text() -> void:
	set_distance(_metres)
	set_score(_points)
	set_best(_best)
	controls_label.text = tr("hint").replace("\\n", "\n")
	horn_button.text = tr("horn")
	fuel_gauge.refresh_text()
	speedometer.refresh_text()
	ride_chip.refresh_text()
	brake_pedal.refresh_text()
	pickup_label.dismiss()


func _fit_value(label: Label, font_size: int, width: float) -> void:
	var font := label.get_theme_font("font")
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted := mini(font_size, floori(font_size * width / maxf(text_width, 1.0)))
	label.add_theme_font_size_override("font_size", maxi(10, fitted))

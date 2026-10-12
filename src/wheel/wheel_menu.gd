class_name WheelMenu
extends Control
## The lucky-wheel screen. Spin asks main for today's spin (a shop action); when the new
## state arrives the wheel turns and settles on the prize. Shows values only.

signal action_chosen(action: String, id: String)
signal closed

var spinning: bool = false
var _settings: WheelSettings
var _view: Dictionary = {"available": false, "prize": -1, "boost": ""}
var _waiting: bool = false
var _time: float = 0.0
var _from: float = 0.0
var _to: float = 0.0

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var wheel: WheelView = $Center/Card/Margin/Content/Wheel
@onready var result: Label = $Center/Card/Margin/Content/Result
@onready var spin_button: Button = $Center/Card/Margin/Content/Spin
@onready var back_button: Button = $Center/Card/Margin/Content/Back


func _ready() -> void:
	spin_button.pressed.connect(_spin)
	back_button.pressed.connect(close)
	set_process(false)


## view: WheelRules.view() (available, prize, boost).
func set_state(settings: WheelSettings, view: Dictionary) -> void:
	_settings = settings
	wheel.set_settings(settings)
	_view = view.duplicate()
	if _waiting and int(_view.prize) >= 0:
		_waiting = false
		_start_spin(int(_view.prize))
	elif not spinning and int(_view.prize) >= 0:
		wheel.angle = wheel.angle_for(int(_view.prize))
		wheel.queue_redraw()
	refresh_text()


func open() -> void:
	refresh_text()
	show()
	(spin_button if spin_button.visible and not spin_button.disabled else back_button).grab_focus()


func close() -> void:
	if not visible:
		return
	if spinning:
		_finish_spin()
	back_button.release_focus()
	hide()
	closed.emit()


func refresh_text() -> void:
	title.text = tr("wheel_title")
	back_button.text = tr("back")
	spin_button.disabled = spinning or not _view.available
	spin_button.text = tr("wheel_spin") if _view.available or spinning else tr("wheel_tomorrow")
	result.text = tr("wheel_hint")
	var prize := int(_view.prize)
	if not spinning and prize >= 0 and _settings != null:
		if _settings.kinds[prize] == "points":
			result.text = tr("wheel_won_points") % _settings.amounts[prize]
		else:
			result.text = tr("wheel_won_boost") % tr("boost_" + _settings.kinds[prize])


func _spin() -> void:
	if spinning or not _view.available:
		return
	_waiting = true
	action_chosen.emit("wheel", "")


func _start_spin(prize: int) -> void:
	spinning = true
	_time = 0.0
	_from = fposmod(wheel.angle, TAU)
	_to = wheel.angle_for(prize) - TAU * _settings.spin_turns
	set_process(true)


## Eases out over spin_seconds so the wheel slows to a stop on the prize.
func _process(delta: float) -> void:
	_time += delta
	var share := clampf(_time / _settings.spin_seconds, 0.0, 1.0)
	wheel.angle = lerpf(_from, _to, 1.0 - pow(1.0 - share, 3.0))
	wheel.queue_redraw()
	if share >= 1.0:
		_finish_spin()


func _finish_spin() -> void:
	spinning = false
	set_process(false)
	wheel.angle = _to
	wheel.queue_redraw()
	refresh_text()
	back_button.grab_focus()

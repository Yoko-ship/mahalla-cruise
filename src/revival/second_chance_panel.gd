class_name SecondChancePanel
extends Control
## The second-chance card: drive on for a price from the wallet, or see the results. A bar
## counts down and declines when it runs out. Shows values from the HUD; emits the choice.

signal chosen(accepted: bool)

var seconds_left: float = 0.0
var _seconds: float = 1.0
var _price: int = 0
var _wallet: int = 0

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var message: Label = $Center/Card/Margin/Content/Message
@onready var wallet_label: Label = $Center/Card/Margin/Content/Wallet
@onready var timer_bar: ProgressBar = $Center/Card/Margin/Content/Timer
@onready var accept_button: Button = $Center/Card/Margin/Content/Accept
@onready var decline_button: Button = $Center/Card/Margin/Content/Decline


func _ready() -> void:
	accept_button.pressed.connect(_choose.bind(true))
	decline_button.pressed.connect(_choose.bind(false))
	set_process(false)


func open(price: int, wallet: int, seconds: float) -> void:
	_price = price
	_wallet = wallet
	_seconds = maxf(0.1, seconds)
	seconds_left = _seconds
	refresh_text()
	timer_bar.value = 1.0
	show()
	set_process(true)
	accept_button.grab_focus()


func close() -> void:
	set_process(false)
	accept_button.release_focus()
	hide()


## Android Back or Escape answers no.
func decline() -> void:
	_choose(false)


func refresh_text() -> void:
	title.text = tr("revive_title")
	message.text = tr("revive_message") % _price
	wallet_label.text = tr("revive_wallet") % _wallet
	accept_button.text = tr("revive_accept") % _price
	decline_button.text = tr("revive_decline")


## Counts down in real time while shown; the drive itself is already stopped.
func _process(delta: float) -> void:
	seconds_left = maxf(0.0, seconds_left - delta)
	timer_bar.value = seconds_left / _seconds
	if seconds_left <= 0.0:
		_choose(false)


func _choose(accepted: bool) -> void:
	if not visible:
		return
	close()
	chosen.emit(accepted)

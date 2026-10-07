class_name ResultsPanel
extends Control
## Run results card. Shows values supplied by the HUD and emits its actions upward.

signal restart_pressed
signal garage_pressed

var _metres: float = 0.0
var _crash_kind: String = "car"
var _points: int = 0
var _som: int = 0
var _dollars: int = 0
var _close_calls: int = 0
var _best: int = 0
var _record: bool = false
var _unsaved: bool = false
var _earned: int = 0
var _wallet: int = 0
var _task_rewards: Array[int] = []

@onready var message_label: Label = $Card/Margin/Content/Message
@onready var result_label: Label = $Card/Margin/Content/Result
@onready var score_result: Label = $Card/Margin/Content/ScoreResult
@onready var best_result: Label = $Card/Margin/Content/BestResult
@onready var money_result: Label = $Card/Margin/Content/MoneyResult
@onready var wallet_result: Label = $Card/Margin/Content/WalletResult
@onready var restart_button: Button = $Card/Margin/Content/Restart
@onready var garage_button: Button = $Card/Margin/Content/Garage


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	garage_button.pressed.connect(func() -> void: garage_pressed.emit())


func open(metres: float, crash_kind: String = "car") -> void:
	_metres = metres
	_crash_kind = crash_kind
	refresh_text()
	show()
	restart_button.grab_focus()


func close() -> void:
	restart_button.release_focus()
	_task_rewards.clear()
	refresh_text()
	hide()


func set_score(points: int, som_count: int, dollar_count: int, close_calls: int) -> void:
	_points = points
	_som = som_count
	_dollars = dollar_count
	_close_calls = close_calls
	refresh_text()


func set_best(points: int, new_record: bool, unsaved: bool) -> void:
	_best = points
	_record = new_record
	_unsaved = unsaved
	refresh_text()


func set_wallet(earned: int, wallet: int, task_rewards: Array[int]) -> void:
	_earned = earned
	_wallet = wallet
	_task_rewards = task_rewards.duplicate()
	refresh_text()


func refresh_text() -> void:
	message_label.text = tr("crash_sheep" if _crash_kind == "sheep" else "crash_message")
	result_label.text = tr("travelled") % int(_metres)
	score_result.text = tr("points") % _points
	money_result.text = tr("notes") % [_som, _dollars]
	if _close_calls > 0:
		money_result.text += "\n" + tr("close_calls") % _close_calls
	best_result.text = tr("new_best" if _record else "best") % _best
	if _unsaved:
		best_result.text += "\n" + tr("unsaved").strip_edges()
	wallet_result.text = tr("wallet_result") % [_earned, _wallet]
	for reward in _task_rewards:
		wallet_result.text += "\n" + tr("task_done") % reward

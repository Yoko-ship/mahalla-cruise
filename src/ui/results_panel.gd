class_name ResultsPanel
extends Control
## Run results card. Shows values supplied by the HUD and emits its actions upward.

signal restart_pressed
signal garage_pressed
## The player wants to share this result; text is ready to send.
signal share_pressed(text: String)

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
var _achievement_rewards: Array[int] = []
## Mahalla drivers passed this drive ({name, reward}) and the next one ahead ({name, score}).
var _rivals: Array = []
var _next_rival: Dictionary = {}

@onready var message_label: Label = $Card/Margin/Content/Message
@onready var result_label: Label = $Card/Margin/Content/Result
@onready var score_result: Label = $Card/Margin/Content/ScoreResult
@onready var best_result: Label = $Card/Margin/Content/BestResult
@onready var money_result: Label = $Card/Margin/Content/MoneyResult
@onready var wallet_result: Label = $Card/Margin/Content/WalletResult
@onready var restart_button: Button = $Card/Margin/Content/Restart
@onready var garage_button: Button = $Card/Margin/Content/Buttons/Garage
@onready var share_button: Button = $Card/Margin/Content/Buttons/Share


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	garage_button.pressed.connect(func() -> void: garage_pressed.emit())
	share_button.pressed.connect(func() -> void: share_pressed.emit(share_text()))


func open(metres: float, crash_kind: String = "car") -> void:
	_metres = metres
	_crash_kind = crash_kind
	refresh_text()
	show()
	restart_button.grab_focus()


func close() -> void:
	restart_button.release_focus()
	_task_rewards.clear()
	_achievement_rewards.clear()
	_rivals.clear()
	_next_rival = {}
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


## booked: what RunRecords.finish() returned; missing parts show nothing.
func set_wallet(earned: int, wallet: int, booked: Dictionary = {}) -> void:
	_earned = earned
	_wallet = wallet
	_task_rewards.assign(booked.get("tasks", []))
	_achievement_rewards.assign(booked.get("unlocked", []))
	_rivals = booked.get("rivals", []).duplicate(true)
	_next_rival = booked.get("next_rival", {}).duplicate()
	refresh_text()


## The message for Telegram, in the current language.
func share_text() -> String:
	return tr("share_text") % [_points, int(_metres)]


func refresh_text() -> void:
	var messages := {"sheep": "crash_sheep", "fuel": "crash_fuel"}
	message_label.text = tr(messages.get(_crash_kind, "crash_message"))
	result_label.text = tr("travelled") % int(_metres)
	score_result.text = tr("points") % _points
	money_result.text = tr("notes") % [_som, _dollars]
	if _close_calls > 0:
		money_result.text += "\n" + tr("close_calls") % _close_calls
	best_result.text = tr("new_best" if _record else "best") % _best
	if _unsaved:
		best_result.text += "\n" + tr("unsaved").strip_edges()
	share_button.text = tr("share")
	wallet_result.text = tr("wallet_result") % [_earned, _wallet]
	for reward in _task_rewards:
		wallet_result.text += "\n" + tr("task_done") % reward
	for reward in _achievement_rewards:
		wallet_result.text += "\n" + tr("achievement_done") % reward
	if _rivals.size() == 1:
		wallet_result.text += "\n" + tr("rival_passed") % [_rivals[0].name, _rivals[0].reward]
	elif _rivals.size() > 1:
		var total := 0
		for rival: Dictionary in _rivals:
			total += rival.reward
		wallet_result.text += "\n" + tr("rivals_passed") % [_rivals.size(), total]
	if not _next_rival.is_empty():
		wallet_result.text += "\n" + tr("rival_next") % [_next_rival.name, _next_rival.score]

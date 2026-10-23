class_name CollectionProgress
extends PanelContainer
## Displays the run's collection target; success time advances only while driving.

var target: int = 0
var collected: int = 0
var success_remaining: float = 0.0
var _bonus: int = 0

@onready var heading: Label = $Margin/Content/Row/Heading
@onready var counter: Label = $Margin/Content/Row/Counter
@onready var bar: ProgressBar = $Margin/Content/Progress


func set_view(view: Dictionary, seconds: float) -> void:
	target = int(view.get("target", 0))
	collected = int(view.get("collected", 0))
	_bonus = int(view.get("bonus", 0))
	if view.is_empty() or view.get("reset", false):
		success_remaining = 0.0
	if view.get("complete", false):
		success_remaining = seconds
	refresh_text()


func advance(delta: float) -> void:
	if success_remaining <= 0.0:
		return
	success_remaining = maxf(0.0, success_remaining - delta)
	if success_remaining == 0.0:
		refresh_text()


func refresh_text() -> void:
	var success := success_remaining > 0.0
	heading.text = tr("collection_complete") if success else tr("collection_goal") % target
	counter.text = "+%d" % _bonus if success else "%d/%d" % [collected, target]
	bar.max_value = maxi(1, target)
	bar.value = target if success else collected

class_name DailyMenu
extends Control
## Lists today's tasks, lifetime achievements, or the mahalla rating, with progress and
## rewards. Read-only; main supplies the lists and the switch button cycles through them.

signal closed

const TEXT_COLOR := Color(1, 0.96, 0.85, 1)
const MUTED_COLOR := Color(0.78, 0.86, 0.81, 1)
const GOLD := Color(1, 0.85, 0.47, 1)

## 0: today's tasks, 1: achievements, 2: the mahalla rating.
var list_index: int = 0
var showing_achievements: bool:
	get:
		return list_index == 1
var _lists: Array = [[], [], []]

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var rows: VBoxContainer = $Center/Card/Margin/Content/Rows
@onready var footer: Label = $Center/Card/Margin/Content/Footer
@onready var switch_button: Button = $Center/Card/Margin/Content/Switch
@onready var back_button: Button = $Center/Card/Margin/Content/Back


func _ready() -> void:
	back_button.pressed.connect(close)
	switch_button.pressed.connect(func() -> void: _show_list(_next_list()))


## Rival rows (see RivalLadder.entries) carry a place and a name; an empty name is the player.
func set_entries(
	entries: Array[Dictionary],
	achievement_entries: Array[Dictionary] = [],
	rival_entries: Array[Dictionary] = []
) -> void:
	_lists = [
		entries.duplicate(true), achievement_entries.duplicate(true), rival_entries.duplicate(true)
	]
	_rebuild()


func open() -> void:
	_show_list(0)
	show()
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	back_button.release_focus()
	hide()
	closed.emit()


func _show_list(index: int) -> void:
	list_index = index
	_rebuild()


func _next_list() -> int:
	for step in range(1, _lists.size()):
		var index := (list_index + step) % _lists.size()
		if index == 0 or not _lists[index].is_empty():
			return index
	return 0


func _shown() -> Array:
	return _lists[list_index]


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in _shown():
		rows.add_child(_row())
	refresh_text()


func refresh_text() -> void:
	var titles := ["daily_title", "achievements", "rating_title"]
	title.text = tr(titles[list_index])
	footer.text = tr(["tasks_footer", "ach_footer", "rating_footer"][list_index])
	switch_button.text = tr(titles[_next_list()])
	switch_button.visible = _next_list() != list_index
	back_button.text = tr("back")
	var entries := _shown()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var row := rows.get_child(index)
		(row.get_node("Layout/Text") as Label).text = _entry_text(entry)
		(row.get_node("Layout/Status/Bar") as ProgressBar).value = (
			float(entry.progress) / maxf(1.0, entry.target)
		)
		var count := row.get_node("Layout/Status/Count") as Label
		count.text = "%d / %d" % [entry.progress, entry.target]
		# The streak row has no counter; its target is the streak day.
		count.visible = entry.get("counter", true)
		var reward := row.get_node("Layout/Status/Reward") as Label
		var done_key := "rating_passed" if entry.has("place") else "task_complete"
		reward.text = tr(done_key) if entry.done else tr("task_reward") % entry.reward
		reward.visible = entry.done or entry.reward > 0
		reward.add_theme_color_override("font_color", GOLD if entry.done else TEXT_COLOR)
		var you: bool = entry.get("name", "-") == ""
		row.self_modulate = Color(1.5, 1.35, 0.9) if you else Color.WHITE


func _entry_text(entry: Dictionary) -> String:
	if entry.has("place"):
		var shown_name: String = (
			entry.name if entry.name != "" else tr("rating_you") % entry.progress
		)
		return "%d. %s" % [entry.place, shown_name]
	return tr(entry.text_key) % entry.target


func _row() -> PanelContainer:
	var row := PanelContainer.new()
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 4)
	row.add_child(layout)
	var text := _label("Text", 15, TEXT_COLOR)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(text)
	var status := HBoxContainer.new()
	status.name = "Status"
	status.add_theme_constant_override("separation", 8)
	layout.add_child(status)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(bar)
	status.add_child(_label("Count", 13, MUTED_COLOR))
	status.add_child(_label("Reward", 13, TEXT_COLOR))
	return row


func _label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

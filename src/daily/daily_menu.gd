class_name DailyMenu
extends Control
## Lists today's tasks, or lifetime achievements, with progress and rewards. Read-only;
## main supplies both lists and the switch button flips between them.

signal closed

const TEXT_COLOR := Color(1, 0.96, 0.85, 1)
const MUTED_COLOR := Color(0.78, 0.86, 0.81, 1)
const GOLD := Color(1, 0.85, 0.47, 1)

var showing_achievements: bool = false
var _entries: Array[Dictionary] = []
var _achievements: Array[Dictionary] = []

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var rows: VBoxContainer = $Center/Card/Margin/Content/Rows
@onready var footer: Label = $Center/Card/Margin/Content/Footer
@onready var switch_button: Button = $Center/Card/Margin/Content/Switch
@onready var back_button: Button = $Center/Card/Margin/Content/Back


func _ready() -> void:
	back_button.pressed.connect(close)
	switch_button.pressed.connect(func() -> void: _show_list(not showing_achievements))


func set_entries(entries: Array[Dictionary], achievement_entries: Array[Dictionary] = []) -> void:
	_entries = entries.duplicate(true)
	_achievements = achievement_entries.duplicate(true)
	_rebuild()


func open() -> void:
	_show_list(false)
	show()
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	back_button.release_focus()
	hide()
	closed.emit()


func _show_list(achievements: bool) -> void:
	showing_achievements = achievements
	_rebuild()


func _shown() -> Array[Dictionary]:
	return _achievements if showing_achievements else _entries


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in _shown():
		rows.add_child(_row())
	refresh_text()


func refresh_text() -> void:
	title.text = tr("achievements" if showing_achievements else "daily_title")
	footer.text = tr("ach_footer" if showing_achievements else "tasks_footer")
	switch_button.text = tr("daily_title" if showing_achievements else "achievements")
	switch_button.visible = not _achievements.is_empty()
	back_button.text = tr("back")
	var entries := _shown()
	for index in range(entries.size()):
		var entry := entries[index]
		var row := rows.get_child(index)
		(row.get_node("Layout/Text") as Label).text = tr(entry.text_key) % entry.target
		(row.get_node("Layout/Status/Bar") as ProgressBar).value = (
			float(entry.progress) / maxf(1.0, entry.target)
		)
		var count := row.get_node("Layout/Status/Count") as Label
		count.text = "%d / %d" % [entry.progress, entry.target]
		# The streak row has no counter; its target is the streak day.
		count.visible = entry.get("counter", true)
		var reward := row.get_node("Layout/Status/Reward") as Label
		reward.text = tr("task_complete") if entry.done else tr("task_reward") % entry.reward
		reward.add_theme_color_override("font_color", GOLD if entry.done else TEXT_COLOR)


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

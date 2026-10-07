class_name GarageMenu
extends Control
## Presents the car roster. Emits choices upward; main validates purchases and saves.

signal car_chosen(id: String)
signal closed

var _catalogue: GarageCatalogue
var _owned: Array[String] = []
var _selected: String = ""
var _wallet: int = 0

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var wallet_label: Label = $Center/Card/Margin/Content/Wallet
@onready var rows: VBoxContainer = $Center/Card/Margin/Content/Rows
@onready var note: Label = $Center/Card/Margin/Content/Note
@onready var back_button: Button = $Center/Card/Margin/Content/Back


func _ready() -> void:
	back_button.pressed.connect(close)


func set_state(
	catalogue: GarageCatalogue, owned: Array[String], selected: String, wallet: int
) -> void:
	if catalogue != _catalogue:
		_catalogue = catalogue
		_rebuild()
	_owned = owned.duplicate()
	_selected = selected
	_wallet = wallet
	refresh_text()


func open() -> void:
	refresh_text()
	show()
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	back_button.release_focus()
	hide()
	closed.emit()


func refresh_text() -> void:
	title.text = tr("garage")
	wallet_label.text = tr("wallet") % _wallet
	back_button.text = tr("back")
	note.text = tr("more_cars")
	note.visible = _catalogue != null and _catalogue.available().size() < _catalogue.cars.size()
	for row: GarageRow in rows.get_children():
		row.refresh(row.car.id in _owned, row.car.id == _selected, _wallet)


func row_for(id: String) -> GarageRow:
	for row: GarageRow in rows.get_children():
		if row.car.id == id:
			return row
	return null


func _rebuild() -> void:
	# Rows are rebuilt only when the roster changes, never during a button press.
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if _catalogue == null:
		return
	for car in _catalogue.available():
		var row := GarageRow.new()
		rows.add_child(row)
		row.setup(car)
		row.chosen.connect(func() -> void: car_chosen.emit(car.id))

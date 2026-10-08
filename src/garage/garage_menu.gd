class_name GarageMenu
extends Control
## Presents the car roster, paints, and upgrades, and opens the market. Emits choices
## upward as shop actions ("car", "paint", "upgrade"); main validates purchases and saves.

signal action_chosen(action: String, id: String)
signal market_pressed
signal closed

var _catalogue: GarageCatalogue
var _view: Dictionary = {"owned": [], "selected": "", "wallet": 0, "paint": "", "colors": {}}

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var wallet_label: Label = $Center/Card/Margin/Content/Wallet
@onready var paint_label: Label = $Center/Card/Margin/Content/PaintLabel
@onready var paints: PaintPicker = $Center/Card/Margin/Content/Paints
@onready var upgrade_label: Label = $Center/Card/Margin/Content/UpgradeLabel
@onready var upgrades: UpgradePicker = $Center/Card/Margin/Content/Upgrades
@onready var rows: VBoxContainer = $Center/Card/Margin/Content/Rows
@onready var note: Label = $Center/Card/Margin/Content/Note
@onready var back_button: Button = $Center/Card/Margin/Content/Buttons/Back
@onready var market_button: Button = $Center/Card/Margin/Content/Buttons/Market


func _ready() -> void:
	back_button.pressed.connect(close)
	market_button.pressed.connect(func() -> void: market_pressed.emit())
	paints.paint_chosen.connect(func(id: String) -> void: action_chosen.emit("paint", id))
	upgrades.upgrade_chosen.connect(func(id: String) -> void: action_chosen.emit("upgrade", id))


## view comes from GarageRules.view(): owned, selected, wallet, paint, owned_paints, colors,
## and upgrades.
func set_state(catalogue: GarageCatalogue, view: Dictionary) -> void:
	if catalogue != _catalogue:
		_catalogue = catalogue
		_rebuild()
		paints.setup(catalogue.paints)
		upgrades.setup(catalogue.upgrades)
	_view = view.duplicate(true)
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
	wallet_label.text = tr("wallet") % _view.wallet
	paint_label.text = tr("paint")
	paints.refresh(_view.paint, _view.get("owned_paints", []), _view.wallet)
	upgrade_label.text = tr("upgrades")
	upgrades.refresh(_view.get("upgrades", {}), _view.wallet)
	back_button.text = tr("back")
	market_button.text = tr("market")
	note.text = tr("more_cars")
	note.visible = _catalogue != null and _catalogue.available().size() < _catalogue.cars.size()
	for row: GarageRow in rows.get_children():
		row.refresh(row.car.id in _view.owned, row.car.id == _view.selected, _view.wallet)
		row.set_paint(_view.colors.get(row.car.id, Color.WHITE))
		row.set_condition(_view.get("conditions", {}).get(row.car.id, 100))


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
		row.chosen.connect(func() -> void: action_chosen.emit("car", car.id))

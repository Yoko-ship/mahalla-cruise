class_name UpgradePicker
extends HBoxContainer
## Upgrade buttons for the selected car: name, level, and the next level's price.

signal upgrade_chosen(id: String)

var buttons: Dictionary = {}


func setup(upgrades: Array[UpgradeDefinition]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	for upgrade in upgrades:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		var id := upgrade.id
		button.pressed.connect(func() -> void: upgrade_chosen.emit(id))
		button.set_meta("upgrade", upgrade)
		add_child(button)
		buttons[id] = button


func refresh(levels: Dictionary, wallet: int) -> void:
	for id: String in buttons:
		var button: Button = buttons[id]
		var upgrade: UpgradeDefinition = button.get_meta("upgrade")
		var level := int(levels.get(id, 0))
		var maxed := level >= upgrade.max_level()
		var price := upgrade.price_for(level)
		var status := tr("upgrade_max") if maxed else str(price)
		button.text = "%s\n%d/%d · %s" % [tr("upgrade_" + id), level, upgrade.max_level(), status]
		button.disabled = maxed or price > wallet
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL

class_name PaintDefinition
extends Resource
## One body color. Bought once, it can be used on every car; factory colors are free.

@export var id: String = ""
@export var color: Color = Color.WHITE
@export_range(0, 100000) var price: int = 150

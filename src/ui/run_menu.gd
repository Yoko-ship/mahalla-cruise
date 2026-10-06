class_name RunMenu
extends Control
## Shared start/pause presentation. The parent routes the primary action.

signal primary_pressed

var is_pause: bool = false

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var subtitle: Label = $Center/Card/Margin/Content/Subtitle
@onready var car: TextureRect = $Center/Card/Margin/Content/Car
@onready var detail: Label = $Center/Card/Margin/Content/Detail
@onready var primary_button: Button = $Center/Card/Margin/Content/Primary


func _ready() -> void:
	primary_button.pressed.connect(func() -> void: primary_pressed.emit())


func show_start(best: int) -> void:
	is_pause = false
	title.text = "Mahalla\nCruise"
	title.add_theme_font_size_override("font_size", 42)
	subtitle.text = "A little drive. A familiar place."
	car.show()
	detail.text = "Best: %d" % best
	primary_button.text = "Play"
	show()
	primary_button.grab_focus()


func show_pause(points: int, metres: float) -> void:
	is_pause = true
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 34)
	subtitle.text = "Continue when you're ready."
	car.hide()
	detail.text = "%d pts  ·  %d m" % [points, int(metres)]
	primary_button.text = "Resume"
	show()
	primary_button.grab_focus()


func close() -> void:
	primary_button.release_focus()
	hide()

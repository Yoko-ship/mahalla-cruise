class_name RunMenu
extends Control
## Shared start/pause presentation. The parent routes the primary action.

signal primary_pressed
signal garage_pressed
signal tasks_pressed
signal route_chosen(id: String)
signal language_selected(locale: String)
signal sound_toggled(enabled: bool)
signal haptics_toggled(enabled: bool)
signal music_toggled(enabled: bool)

var is_pause: bool = false
var _best: int = 0
var _points: int = 0
var _metres: float = 0.0

@onready var title: Label = $Center/Card/Margin/Content/Title
@onready var subtitle: Label = $Center/Card/Margin/Content/Subtitle
@onready var car: TextureRect = $Center/Card/Margin/Content/Car
@onready var plate_view: PlateView = $Center/Card/Margin/Content/Plate
@onready var route_picker: RoutePicker = $Center/Card/Margin/Content/Route
@onready var detail: Label = $Center/Card/Margin/Content/Detail
@onready var primary_button: Button = $Center/Card/Margin/Content/Actions/Primary
@onready var garage_button: Button = $Center/Card/Margin/Content/Actions/Garage
@onready var tasks_button: Button = $Center/Card/Margin/Content/Actions/Tasks
@onready var preferences: MenuPreferences = $Center/Card/Margin/Content/Preferences
@onready var instructions: Label = $Center/Card/Margin/Content/Instructions


func _ready() -> void:
	primary_button.pressed.connect(func() -> void: primary_pressed.emit())
	garage_button.pressed.connect(func() -> void: garage_pressed.emit())
	tasks_button.pressed.connect(func() -> void: tasks_pressed.emit())
	route_picker.route_chosen.connect(func(id: String) -> void: route_chosen.emit(id))
	# Play waits while a locked city is shown; Resume never depends on it.
	route_picker.browsing_locked.connect(
		func(locked: bool) -> void: primary_button.disabled = locked and not is_pause
	)
	preferences.language_selected.connect(
		func(locale: String) -> void: language_selected.emit(locale)
	)
	preferences.sound_toggled.connect(func(enabled: bool) -> void: sound_toggled.emit(enabled))
	preferences.haptics_toggled.connect(func(enabled: bool) -> void: haptics_toggled.emit(enabled))
	preferences.music_toggled.connect(func(enabled: bool) -> void: music_toggled.emit(enabled))


func show_start(best: int) -> void:
	is_pause = false
	_best = best
	refresh_text()
	show()
	primary_button.grab_focus()


func show_pause(points: int, metres: float) -> void:
	is_pause = true
	_points = points
	_metres = metres
	refresh_text()
	show()
	primary_button.grab_focus()


func refresh_text() -> void:
	title.text = tr("paused") if is_pause else "Mahalla\nCruise"
	title.add_theme_font_size_override("font_size", 34 if is_pause else 42)
	subtitle.text = tr("pause_message") if is_pause else tr("tagline")
	car.visible = not is_pause
	plate_view.visible = not is_pause
	route_picker.visible = not is_pause
	route_picker.refresh_text()
	primary_button.disabled = route_picker.is_locked() and not is_pause
	detail.text = (tr("run_summary") % [_points, int(_metres)] if is_pause else tr("best") % _best)
	primary_button.text = tr("resume") if is_pause else tr("play")
	garage_button.text = tr("garage")
	garage_button.visible = not is_pause
	tasks_button.text = tr("tasks")
	tasks_button.visible = not is_pause
	instructions.text = tr("hint").replace("\\n", "\n")


func set_car(texture: Texture2D, paint: Color) -> void:
	car.texture = texture
	if not car.material is ShaderMaterial:
		car.material = ShaderMaterial.new()
		car.material.shader = CarVisual.PAINT_SHADER
	car.material.set_shader_parameter("paint", paint)


## view comes from GarageRules.view(): routes, route, plate, and wallet.
func set_garage(routes: Array[RouteDefinition], view: Dictionary) -> void:
	if route_picker.routes != routes:
		route_picker.setup(routes)
	route_picker.refresh(view.routes, view.route, view.wallet)
	plate_view.code = view.plate


func set_options(sound: bool, haptics: bool, unsaved: bool, music: bool = true) -> void:
	preferences.set_options(sound, haptics, unsaved, music)


func close() -> void:
	primary_button.release_focus()
	hide()

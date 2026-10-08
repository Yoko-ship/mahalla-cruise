extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const AUDIO: AudioSettings = preload("res://src/audio/default_audio.tres")

var failures: int = 0
var checks: int = 0
var _path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://audio_test_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	await _test_music_follows_the_drive()
	await _test_horn()
	await _test_music_preference()
	_cleanup()
	await create_timer(0.4).timeout
	if failures == 0:
		print(
			"PASS: music loop, run-state music, horn, and saved music option (%d checks)" % checks
		)
	quit(1 if failures else 0)


func _test_music_follows_the_drive() -> void:
	var game := _new_game("")
	var music := game.audio.music
	_check(music.stream is AudioStreamWAV, "Music is an imported WAV")
	_check((music.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
	_check(is_equal_approx(music.volume_db, AUDIO.music_volume_db), "Music uses its volume")
	_check(not _audible(music), "Menus stay quiet")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(_audible(music), "Music plays during a drive")
	game.pause_run()
	_check(not _audible(music), "Pause pauses the music")
	game.resume_run()
	_check(_audible(music), "Resume continues the music")
	game.audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _audible(music), "Leaving the app silences music")
	game.audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.world.traffic.contacted.emit()
	_check(not _audible(music), "A crash stops the music")
	game.restart_run()
	game.world.player.set_physics_process(false)
	_check(_audible(music), "Drive again restarts the music")
	game.free()


func _test_horn() -> void:
	var game := _new_game("")
	_check(not game.hud.drive.horn_button.visible, "The horn is hidden in menus")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(game.hud.drive.horn_button.visible, "The horn appears while driving")
	_check(game.hud.drive.horn_button.text == "Beep!", "The horn label is translated")
	await _click(game.hud.drive.horn_button)
	_check(game.audio.horn.playing, "Tapping the horn honks")
	_check(
		game.world.player.target_x == game.world.player.position.x,
		"Tapping the horn does not steer"
	)
	game.audio.horn.stop()
	game.hud.drive.horn_button.pressed.emit()
	_check(not game.audio.horn.playing, "The horn has a short cooldown")
	game.hud.sound_toggled.emit(false)
	await create_timer(AUDIO.horn_cooldown_ms / 1000.0 + 0.05).timeout
	game.hud.drive.horn_button.pressed.emit()
	_check(not game.audio.horn.playing, "Sound off silences the horn")
	game.pause_run()
	_check(not game.hud.drive.horn_button.visible, "The horn hides when paused")
	game.free()


func _test_music_preference() -> void:
	_cleanup()
	var game := _new_game(_path)
	var button := game.hud.menu.preferences.music_button
	_check(button.text == "Music on" and button.button_pressed, "Music starts enabled")
	await _click(button)
	_check(not game.progress.music_enabled and button.text == "Music off", "Music can be off")
	game.start_run()
	game.world.player.set_physics_process(false)
	_check(not _audible(game.audio.music), "Disabled music stays quiet while driving")
	_check(game.pickup_feedback.sound_enabled, "Music off keeps sound effects on")
	game.free()
	var reopened := _new_game(_path)
	_check(not reopened.progress.music_enabled, "The music choice survives relaunch")
	_check(reopened.hud.menu.preferences.music_button.text == "Music off", "And shows in menus")
	reopened.free()


func _audible(music: AudioStreamPlayer) -> bool:
	return music.playing and not music.stream_paused


func _new_game(path: String) -> CruiseGame:
	var game := MAIN_SCENE.instantiate() as CruiseGame
	(game.get_node("Progress") as LocalProgressStore).save_path = path
	game.traffic_settings = game.traffic_settings.duplicate() as TrafficSettings
	game.traffic_settings.first_spawn_distance = 100000.0
	root.add_child(game)
	game.set_language("en")
	game.set_process(false)
	return game


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

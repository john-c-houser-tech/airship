extends Node2D
## The window: it gives the core the time that passed and the keys pressed,
## and shows what the core says changed. All the rules are in core/; the
## desktop (the theme's accent, notify-send) is in desktop/; the drawing is
## in scene/.
##
## How often it draws (gate C): 30 frames a second while the arm moves, a few
## while it rests, and next to nothing between sessions, when nothing moves
## but Space must still answer at once.
##
## Flags after `--`, for checks and pictures: --shot=PATH saves a frame and
## quits; --check also checks the frame (bin/test's, at a pinned clear noon);
## --build=SECONDS starts a session that many seconds in; --give-up then gives
## it up; --give-up-at=SECONDS and --quit-at=SECONDS do so that long after
## start, --log-sounds says when a sound starts and stops, and --log-words
## says the first line shown (bin/test's headless runs). Pictures keep their
## plants in a throwaway garden, never the real one. AIRSHIP_DATE,
## AIRSHIP_TIME and AIRSHIP_WEATHER pin the sky, and AIRSHIP_LANGUAGE the
## language.

const Backdrop := preload("res://scene/backdrop.gd")
const Machinery := preload("res://scene/machinery.gd")
const Workshop := preload("res://scene/workshop.gd")
const WeatherLayer := preload("res://scene/weather_layer.gd")
const Hud := preload("res://scene/hud.gd")

# Godot waits the longer of 1/max_fps and the low-processor sleep between
# turns of its loop, input included: so Space answers within about a sixth
# of a second at rest and a tenth between sessions.
const WORKING_FPS := 30
const RESTING_FPS := 6
const IDLE_FPS := 10
const IDLE_SLEEP_USEC := 100_000
const DEFAULT_SLEEP_USEC := 6900
# The steam takes this long to die away after the arm stops.
const STEAM_FADE_SECONDS := 3.5
const LIGHT_EVERY_MS := 60_000
const THEME_EVERY_MS := 2_000
const SHOT_FRAMES := 4

var app: App
var theme: DesktopTheme
var language: DesktopLanguage
var notifier: Notifier

var _backdrop: Backdrop
var _machinery: Machinery
var _workshop: Workshop
var _weather: WeatherLayer
var _hud: Hud
var _player: AudioStreamPlayer
var _fade: Tween
var _carry_ms := 0.0
var _since_light_ms := 0.0
var _since_theme_ms := 0.0
var _shot_path := ""
var _check := false
var _give_up_at := -1.0
var _quit_at := -1.0
var _log_sounds := false
var _alive_ms := 0.0
var _was_playing := false
var _frames := 0


func _ready() -> void:
	_plain_title.call_deferred()
	var options := Options.from_environment()
	var build := -1
	var give_up := false
	var log_words := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg == "--check":
			_check = true
		elif arg.begins_with("--build="):
			build = arg.trim_prefix("--build=").to_int()
		elif arg == "--give-up":
			give_up = true
		elif arg.begins_with("--give-up-at="):
			_give_up_at = arg.trim_prefix("--give-up-at=").to_float()
		elif arg.begins_with("--quit-at="):
			_quit_at = arg.trim_prefix("--quit-at=").to_float()
		elif arg == "--log-sounds":
			_log_sounds = true
		elif arg == "--log-words":
			log_words = true
	if (build >= 0 or not _shot_path.is_empty()) and options.garden_path.is_empty():
		# A picture's plants are make-believe: never in the real garden.
		var throwaway := OS.get_user_data_dir().path_join("pictures")
		OS.execute("rm", ["-rf", throwaway])
		options.garden_path = throwaway.path_join("garden.json")
	app = App.new(options)
	theme = DesktopTheme.new(options.theme_directory)
	app.set_accent(theme.accent)
	language = DesktopLanguage.new(options.language_file)
	app.set_language(language.code)
	notifier = Notifier.new()
	_backdrop = Backdrop.new()
	_machinery = Machinery.new()
	_workshop = Workshop.new()
	_weather = WeatherLayer.new()
	_hud = Hud.new()
	for layer: Node2D in [_backdrop, _machinery, _workshop, _weather, _hud]:
		add_child(layer)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_workshop.time_scale = app.session.seconds() / Workshop.BuildPlan.SESSION
	_hud.notices_work = notifier.working
	if build >= 0:
		app.start(0, 12345)
		app.advance(build * 1000)
		if give_up:
			app.give_up()
	_show_everything()
	if log_words:
		print("says: " + _hud.next_step())


## Arch's godot is the editor build, which marks the window's title
## " (DEBUG)" each time Godot sets it (at start, and again when it applies its
## language settings). Set on the display itself, after Godot, it stays plain.
func _plain_title() -> void:
	DisplayServer.window_set_title("Airship")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_plain_title.call_deferred()


func _process(delta: float) -> void:
	# Whole milliseconds to the core, the fractions carried to the next frame.
	_carry_ms += delta * 1000.0
	var ms := int(_carry_ms)
	_carry_ms -= ms
	var events := app.advance(ms)
	_since_light_ms += delta * 1000.0
	if _since_light_ms >= LIGHT_EVERY_MS:
		_since_light_ms = 0.0
		events.append_array(app.refresh_light())
	_since_theme_ms += delta * 1000.0
	if _since_theme_ms >= THEME_EVERY_MS:
		_since_theme_ms = 0.0
		if theme.reload():
			events.append_array(app.set_accent(theme.accent))
		if language.reload():
			events.append_array(app.set_language(language.code))
	_heard(events)
	# While building, the arm follows the clock every frame (as often as the
	# pace allows), so it sets off again the moment its rest is over.
	if app.session.state() == Session.State.BUILDING:
		_workshop.show_session(Session.State.BUILDING, app.session.progress())
	_pace()
	_alive_ms += delta * 1000.0
	if _give_up_at >= 0.0 and _alive_ms >= _give_up_at * 1000.0:
		_give_up_at = -1.0
		_heard(app.give_up())
	if _log_sounds and _player.playing != _was_playing:
		_was_playing = _player.playing
		print("sound: %s" % (Sounds.NAMES[app.sound] if _was_playing else "stopped"))
	if _quit_at >= 0.0 and _alive_ms >= _quit_at * 1000.0:
		get_tree().quit()
	if not _shot_path.is_empty():
		_frames += 1
		if _frames >= SHOT_FRAMES:
			_take_shot()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return
	if key.keycode == KEY_M:
		_heard(app.set_muted(not app.muted))
		return
	if key.keycode != KEY_SPACE:
		return
	if app.session.state() == Session.State.BUILDING:
		_heard(app.give_up())
	else:
		_heard(app.start(0, randi_range(1, Session.SEED_LIMIT)))
	_pace()


## Shows what the core says changed.
func _heard(events: Array[int]) -> void:
	for event: int in events:
		match event:
			App.Event.STATE, App.Event.PROGRESS:
				_workshop.show_session(app.session.state(), app.session.progress())
				_hud.state = app.session.state()
				_hud.remaining = app.session.remaining()
				_hud.queue_redraw()
			App.Event.WEATHER, App.Event.LIGHT:
				_show_sky()
			App.Event.GARDEN_PROBLEM:
				_hud.garden_problem = app.garden.problem()
				_hud.save_error = app.garden.save_error
				_hud.queue_redraw()
			App.Event.LANGUAGE:
				_hud.catalog = app.catalog
				_hud.queue_redraw()
			App.Event.SOUND:
				if not app.muted and _shot_path.is_empty():
					_play(app.sound)
			App.Event.SOUNDS_ENDED:
				_fade_out(2.0)
			App.Event.MUTED:
				_hud.muted = app.muted
				_hud.queue_redraw()
				if app.muted:
					_fade_out(0.3)
			App.Event.PLANT_BUILT:
				if _shot_path.is_empty():
					notifier.send(app.say("Built"), app.say("The arm has finished. Take a five-minute break."))
					_hud.notices_work = notifier.working
					_hud.queue_redraw()


func _show_everything() -> void:
	_heard([App.Event.STATE, App.Event.GARDEN_PROBLEM, App.Event.LANGUAGE])
	_hud.muted = app.muted
	_show_sky()
	_pace()


func _show_sky() -> void:
	_backdrop.daylight = app.daylight
	_backdrop.cloud = app.weather.now().cloud
	_weather.daylight = app.daylight
	_weather.conditions = app.weather.now()
	_backdrop.queue_redraw()
	_weather.queue_redraw()


## Plays a distant sound, made ahead of time by bin/make-sounds (the package
## build and bin/test run it). Without it, Airship is simply quiet.
func _play(kind: Sounds.Kind) -> void:
	# Silent, missing, or one already playing: a sound that came due behind
	# another (sounds pile up after the laptop wakes) is let go, as in Grove.
	if app.volume(kind) <= 0.0 or not ResourceLoader.exists(Sounds.FILES[kind]):
		return
	if _player.playing and (_fade == null or not _fade.is_running()):
		return
	if _fade != null:
		_fade.kill()
	_player.stream = load(Sounds.FILES[kind]) as AudioStream
	_player.volume_db = linear_to_db(app.volume(kind))
	_player.play()


## Fades out a sound still playing, and stops it.
func _fade_out(seconds: float) -> void:
	if not _player.playing:
		return
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, seconds)
	_fade.tween_callback(_player.stop)


## Draws as often as what's on screen needs.
func _pace() -> void:
	var building := app.session.state() == Session.State.BUILDING
	if building and _workshop.resting_for() < STEAM_FADE_SECONDS:
		Engine.max_fps = WORKING_FPS
		OS.low_processor_usage_mode_sleep_usec = DEFAULT_SLEEP_USEC
	elif building:
		Engine.max_fps = RESTING_FPS
		OS.low_processor_usage_mode_sleep_usec = DEFAULT_SLEEP_USEC
	else:
		Engine.max_fps = IDLE_FPS
		OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC


## Saves the frame and, with --check, checks it: at bin/test's clear noon
## the sky's corner is the colour the core says, the boiler is brass and the
## ground is green, so a scene that lost its sky, its machinery or its land
## fails. Exit code 0 if it passes.
func _take_shot() -> void:
	set_process(false)
	var image := get_viewport().get_texture().get_image()
	image.save_png(_shot_path)
	if not _check:
		get_tree().quit(0)
		return
	var problems: Array[String] = []
	if not app.weather.now().equals(Weather.conditions_of(Weather.Kind.CLEAR)):
		problems.append("the check needs clear weather (AIRSHIP_WEATHER=clear)")
	var corner := image.get_pixel(4, 4)
	var sky := app.daylight.top
	if absf(corner.r - sky.r) > 0.03 or absf(corner.g - sky.g) > 0.03 or absf(corner.b - sky.b) > 0.03:
		problems.append("the sky's corner is %s, the core's sky is %s" % [corner, sky])
	var boiler := image.get_pixel(73, 560)
	if not (boiler.r > 0.4 and boiler.r > boiler.g and boiler.g > boiler.b):
		problems.append("the boiler isn't brass: %s" % boiler)
	var ground := image.get_pixel(700, 700)
	if not (ground.g > ground.r and ground.g > ground.b):
		problems.append("the ground isn't green: %s" % ground)
	for problem: String in problems:
		printerr("frame check failed: " + problem)
	get_tree().quit(0 if problems.is_empty() else 1)

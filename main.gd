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
## start, --log-sounds says when a sound starts and stops, --log-words says
## the first line shown (bin/test's headless runs), and --log-frames counts
## the frames actually drawn each second (to see what costs CPU). Pictures keep their
## plants in a throwaway garden, never the real one. AIRSHIP_DATE,
## AIRSHIP_TIME and AIRSHIP_WEATHER pin the sky, and AIRSHIP_LANGUAGE the
## language.

const Hangar := preload("res://scene/hangar.gd")
const Passers := preload("res://scene/passers.gd")
const Falling := preload("res://scene/falling.gd")
const Machinery := preload("res://scene/machinery.gd")
const Workshop := preload("res://scene/workshop.gd")
const Hud := preload("res://scene/hud.gd")
# The hangar's lamplight on the arm and plant, by day (the machinery lights
# itself, as the hangar does).
const WORKSHOP_TINT := Color(0.86, 0.80, 0.72)

# Godot waits the longer of 1/max_fps and the low-processor sleep between
# turns of its loop, input included: so Space answers within about a sixth
# of a second at rest and a tenth between sessions.
const WORKING_FPS := 30
const RESTING_FPS := 6
# Falling snow is slow enough for this; rain needs WORKING_FPS.
const SNOW_FPS := 15
# Lighter than this, rain and snow don't set the pace.
const FALLING_THRESHOLD := 0.15
const IDLE_FPS := 10
const IDLE_SLEEP_USEC := 100_000
const DEFAULT_SLEEP_USEC := 6900
# The steam takes this long to die away after the arm stops.
const STEAM_FADE_SECONDS := 3.5
const LIGHT_EVERY_MS := 60_000
const THEME_EVERY_MS := 2_000
const SHOT_FRAMES := 4
# Pixels the frame check reads: sky through the door, the boiler, the floor.
const SKY_PIXEL := Vector2i(300, 275)
const BOILER_PIXEL := Vector2i(40, 600)
const FLOOR_PIXEL := Vector2i(640, 690)

var app: App
var theme: DesktopTheme
var language: DesktopLanguage
var notifier: Notifier

# The hangar is painted into two pictures only when it changes, and the
# pictures are shown every frame: replaying thousands of shapes each frame
# cost 69% of a core on John's desktop while the arm worked. The outside
# (sky, clouds, land, railway) and the inside (the garden, the weather, the
# hangar and the airship, clear where the door shows the outside) are apart
# so the passers-by go between them.
var _outside: Hangar
var _hangar: Hangar
var _paints: Array[SubViewport] = []
var _pictures: Array[Sprite2D] = []
var _passers: Passers
var _falling: Falling
# What is passing (Sounds.Kind, -1 for nothing) and when its sound began, in
# milliseconds of the window's own clock; or a moment pinned by --passing.
var _passing := -1
var _passing_since_ms := 0.0
var _passing_pinned := -1.0
var _machinery: Machinery
var _workshop: Workshop
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
# --log-frames: frames actually drawn, counted and printed each second.
var _frames_drawn := 0
var _frames_since_ms := 0.0
var _log_frames := false
var _alive_ms := 0.0
var _was_playing := false
var _frames := 0


func _ready() -> void:
	_plain_title.call_deferred()
	var options := Options.from_environment()
	var build := -1
	var plant := 0
	var give_up := false
	var log_words := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg == "--check":
			_check = true
		elif arg.begins_with("--plant="):
			# Which blueprint a picture's session builds (with --build).
			plant = arg.trim_prefix("--plant=").to_int()
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
		elif arg.begins_with("--passing="):
			# A passer-by pinned at a moment, for pictures: train:26.
			var parts := arg.trim_prefix("--passing=").split(":")
			_passing = Sounds.named(parts[0])
			_passing_pinned = parts[1].to_float() if parts.size() > 1 else 0.0
		elif arg == "--log-frames":
			_log_frames = true
			RenderingServer.frame_post_draw.connect(func() -> void: _frames_drawn += 1)
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
	_outside = _picture_of(Hangar.Painting.OUTSIDE)
	_hangar = _picture_of(Hangar.Painting.INSIDE)
	_passers = Passers.new()
	_falling = Falling.new()
	_machinery = Machinery.new()
	_workshop = Workshop.new()
	_hud = Hud.new()
	for layer: Node2D in [_pictures[0], _passers, _falling, _pictures[1], _machinery, _workshop, _hud]:
		add_child(layer)
	_fit_hangar_picture()
	get_window().size_changed.connect(_fit_hangar_picture)
	# The corner and the passers-by are seen through the hangar's camera.
	for seen: Node2D in [_machinery, _workshop, _passers]:
		seen.call("stand_in", _hangar)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_workshop.time_scale = app.session.seconds() / Workshop.BuildPlan.SESSION
	_hud.notices_work = notifier.working
	if build >= 0:
		app.start(plant, 12345)
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
	_show_passing()
	# While building, the arm follows the clock every frame (as often as the
	# pace allows), so it sets off again the moment its rest is over.
	if app.session.state() == Session.State.BUILDING:
		_workshop.show_session(Session.State.BUILDING, app.session.progress())
	_pace()
	_alive_ms += delta * 1000.0
	if _log_frames:
		_frames_since_ms += delta * 1000.0
		if _frames_since_ms >= 1000.0:
			print("frames drawn: %d in %.1f s" % [_frames_drawn, _frames_since_ms / 1000.0])
			_frames_drawn = 0
			_frames_since_ms = 0.0
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
	if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
		_heard(app.choose(-1 if key.keycode == KEY_LEFT else 1))
		return
	if key.keycode != KEY_SPACE:
		return
	if app.session.state() == Session.State.BUILDING:
		_heard(app.give_up())
	else:
		_heard(app.start(app.blueprint(), randi_range(1, Session.SEED_LIMIT)))
	_pace()


## Shows what the core says changed.
func _heard(events: Array[int]) -> void:
	for event: int in events:
		match event:
			App.Event.STATE, App.Event.PROGRESS:
				if event == App.Event.STATE:
					# Rain and snow move while the arm works, and are still otherwise.
					_show_sky()
				_workshop.show_blueprint(app.session.blueprint())
				_workshop.show_session(app.session.state(), app.session.progress())
				_hud.state = app.session.state()
				_hud.remaining = app.session.remaining()
				_hud.queue_redraw()
			App.Event.WEATHER, App.Event.LIGHT, App.Event.GARDEN:
				_show_sky()
				if event == App.Event.GARDEN:
					# A new plant changes which one the ship needs next.
					_hud.next_plant = Parts.kind_of(app.blueprint())
					_hud.queue_redraw()
			App.Event.BLUEPRINT:
				_hud.next_plant = Parts.kind_of(app.blueprint())
				_hud.queue_redraw()
			App.Event.GARDEN_PROBLEM:
				_hud.garden_problem = app.garden.problem()
				_hud.save_error = app.garden.save_error
				_hud.queue_redraw()
			App.Event.LANGUAGE:
				_hud.catalog = app.catalog
				_hud.queue_redraw()
			App.Event.SOUND:
				# Its picture passes by whether or not the sound is heard; one
				# that comes due while another passes is let go, as its sound
				# is.
				if _passing < 0:
					_passing = app.sound
					_passing_since_ms = _alive_ms
					_passing_pinned = -1.0
					if _log_sounds:
						print("passing: %s" % Sounds.NAMES[app.sound])
					if not app.muted and _shot_path.is_empty():
						_play(app.sound)
			App.Event.SOUNDS_ENDED:
				_fade_out(2.0)
				_stop_passing()
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
	_heard([App.Event.STATE, App.Event.BLUEPRINT, App.Event.GARDEN_PROBLEM, App.Event.LANGUAGE])
	_hud.muted = app.muted
	_show_sky()
	_pace()


## The hangar and what's seen through its door: drawn again only when the
## light, the weather or the garden (and so the airship) changes.
func _show_sky() -> void:
	# The built plants' kinds, oldest first.
	var plants: Array[int] = []
	for plant: Garden.Plant in app.garden.plants():
		if plant.outcome == Garden.Outcome.BUILT:
			plants.append(Parts.kind_of(plant.blueprint))
	plants.reverse()
	var moving := app.session.state() == Session.State.BUILDING
	var now := app.weather.now()
	_falling.show_weather(now.rain, now.snow, moving, 0.35 + 0.65 * app.daylight.ambient)
	var built := app.airship_progress()
	_outside.show_world(app.daylight, now, built, plants, moving)
	if _hangar.show_world(app.daylight, now, built, plants, moving):
		for paint: SubViewport in _paints:
			paint.render_target_update_mode = SubViewport.UPDATE_ONCE
		_machinery.queue_redraw()
		_passers.queue_redraw()
	var lamplight := 0.45 + 0.55 * app.daylight.ambient
	# The golden hour reaches the corner too.
	var tint := Color(WORKSHOP_TINT * lamplight, 1.0).lerp(app.daylight.warm, app.daylight.warmth * 0.2)
	_workshop.modulate = tint


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


## Sizes the hangar's picture to the window's real pixels, so it stays sharp
## (the scene is laid out on a 760-unit square, stretched to the window).
func _fit_hangar_picture() -> void:
	var window := get_window().size
	var side := maxi(mini(window.x, window.y), 1)
	if side == _paints[0].size.x:
		return
	for k in _paints.size():
		_paints[k].size = Vector2i(side, side)
		(_paints[k].get_child(0) as Hangar).scale = Vector2.ONE * (side / Hangar.SIZE)
		_pictures[k].scale = Vector2.ONE * (Hangar.SIZE / side)
		(_paints[k].get_child(0) as Hangar).queue_redraw()
		_paints[k].render_target_update_mode = SubViewport.UPDATE_ONCE


## A part of the hangar, painted off screen into a picture shown each frame.
func _picture_of(which: Hangar.Painting) -> Hangar:
	var painter := Hangar.new()
	painter.painting = which
	var paint := SubViewport.new()
	# The inside is clear where the door shows the outside.
	paint.transparent_bg = which == Hangar.Painting.INSIDE
	paint.render_target_update_mode = SubViewport.UPDATE_DISABLED
	paint.add_child(painter)
	add_child(paint)
	var picture := Sprite2D.new()
	picture.centered = false
	picture.texture = paint.get_texture()
	if which == Hangar.Painting.INSIDE:
		# Godot's own clear pictures hold premultiplied colour: blended as
		# plain alpha, glows and the golden hour's warmth turned to dark
		# halos over the view.
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		picture.material = blend
	_paints.append(paint)
	_pictures.append(picture)
	return painter


## Moves whatever is passing outside to where it is now: where its sound
## has got to, while it plays (so the picture keeps with it, even after the
## laptop wakes), else the window's own clock (muted).
func _show_passing() -> void:
	if _passing < 0:
		return
	var seconds := (_alive_ms - _passing_since_ms) / 1000.0
	if _passing_pinned >= 0.0:
		seconds = _passing_pinned
	elif _player.playing and _player.stream == load(Sounds.FILES[_passing]):
		seconds = _player.get_playback_position()
	_passers.show_passing(_passing, seconds)
	if not _passers.passing():
		_stop_passing()


func _stop_passing() -> void:
	if _passing < 0:
		return
	_passing = -1
	_passers.show_passing(-1, 0.0)
	if _log_sounds:
		print("passing: stopped")


## Draws as often as what's on screen needs.
func _pace() -> void:
	var building := app.session.state() == Session.State.BUILDING
	var raining := building and app.weather.now().rain > FALLING_THRESHOLD
	var snowing := building and app.weather.now().snow > FALLING_THRESHOLD
	if (building and _workshop.resting_for() < STEAM_FADE_SECONDS) or (_passing >= 0 and _passing_pinned < 0.0) or raining:
		Engine.max_fps = WORKING_FPS
		OS.low_processor_usage_mode_sleep_usec = DEFAULT_SLEEP_USEC
	elif building:
		Engine.max_fps = SNOW_FPS if snowing else RESTING_FPS
		OS.low_processor_usage_mode_sleep_usec = DEFAULT_SLEEP_USEC
	else:
		Engine.max_fps = IDLE_FPS
		OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC


## Saves the frame and, with --check, checks it: at bin/test's clear noon
## the sky through the door is the colour the core says, the boiler is brass
## and the floor is wood, so a scene that lost its sky, its machinery or its
## hangar fails. Exit code 0 if it passes.
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
	var through_door := image.get_pixel(SKY_PIXEL.x, SKY_PIXEL.y)
	var sky := _outside.clear_sky_at(app.daylight, SKY_PIXEL.y)
	if absf(through_door.r - sky.r) > 0.04 or absf(through_door.g - sky.g) > 0.04 or absf(through_door.b - sky.b) > 0.04:
		problems.append("the sky through the door is %s, the core's sky there is %s" % [through_door, sky])
	var boiler := image.get_pixel(BOILER_PIXEL.x, BOILER_PIXEL.y)
	if not (boiler.r > 0.35 and boiler.r > boiler.g and boiler.g > boiler.b):
		problems.append("the boiler isn't brass: %s" % boiler)
	var boards := image.get_pixel(FLOOR_PIXEL.x, FLOOR_PIXEL.y)
	if not (boards.r > boards.g and boards.g > boards.b and boards.r > 0.25):
		problems.append("the floor isn't wood: %s" % boards)
	for problem: String in problems:
		printerr("frame check failed: " + problem)
	get_tree().quit(0 if problems.is_empty() else 1)

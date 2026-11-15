extends TestCase
## How the app turns what a session did into events for the window.


func _app(seconds: int, name := "app") -> App:
	var folder := OS.get_user_data_dir().path_join("app-tests").path_join(name)
	OS.execute("rm", ["-rf", folder])
	var options := Options.new()
	options.seconds = seconds
	options.weather = "clear"
	options.garden_path = folder.path_join("garden.json")
	var app := App.new(options)
	app.clock = func() -> String: return "2026-11-14T10:00:00"
	return app


func test_the_session_length_comes_from_the_options() -> void:
	same(_app(30).session.seconds(), 30, "seconds")


func test_starting_says_the_state_and_progress_changed() -> void:
	var app := _app(10)
	same(app.start(1, 7), [App.Event.STATE, App.Event.PROGRESS, App.Event.WEATHER] as Array[int], "events")


func test_a_tick_too_small_to_see_says_nothing() -> void:
	var app := _app(25 * 60)
	app.start(1, 7)
	same(app.advance(50), [] as Array[int], "events")


func test_finishing_says_both() -> void:
	var app := _app(10)
	app.start(1, 7)
	same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS, App.Event.GARDEN, App.Event.PLANT_BUILT] as Array[int], "events")
	same(app.session.state(), Session.State.BUILT, "state")


func test_giving_up_says_the_state_changed() -> void:
	var app := _app(10)
	app.start(1, 7)
	same(app.give_up(), [App.Event.STATE, App.Event.GARDEN] as Array[int], "events")
	same(app.give_up(), [] as Array[int], "a second give-up")


func test_a_finished_session_keeps_a_built_plant() -> void:
	var app := _app(120, "built")
	app.start(4, 9)
	app.advance(120_000)
	var plant := app.garden.plants()[0]
	same(plant.outcome, Garden.Outcome.BUILT, "outcome")
	same([plant.blueprint, plant.plant_seed, plant.minutes], [4, 9, 2], "blueprint, seed, minutes")
	same(plant.progress, 1.0, "progress")
	same(plant.when, "2026-11-14T10:00:00", "when")
	same(app.garden_change, Garden.Change.RESET, "saved, so the list was read again")
	same(Garden.new(app.options.garden_path).plants().size(), 1, "saved to the file")


func test_giving_up_keeps_a_rusted_plant_that_earns_nothing() -> void:
	var app := _app(100, "rusted")
	app.start(4, 9)
	app.advance(40_000)
	app.give_up()
	var plant := app.garden.plants()[0]
	same(plant.outcome, Garden.Outcome.RUSTED, "outcome")
	same(plant.progress, 0.4, "the size it reached")
	same(plant.minutes, 0, "minutes")


func test_a_garden_that_cannot_be_kept_says_so_once() -> void:
	var options := Options.new()
	options.weather = "clear"
	var app := App.new(options)
	app.start(1, 1)
	var first := app.advance(25 * 60 * 1000)
	check(App.Event.GARDEN in first and App.Event.GARDEN_PROBLEM in first, "the first plant: shown, and the problem said")
	same(app.garden.problem(), Garden.Problem.NO_FOLDER, "problem")
	same(app.garden_change, Garden.Change.INSERTED, "shown, not saved")
	app.start(1, 2)
	var second := app.advance(25 * 60 * 1000)
	check(App.Event.GARDEN in second and not App.Event.GARDEN_PROBLEM in second, "the second: not said again")


func test_a_shortened_session_is_not_kept_without_a_garden_of_its_own() -> void:
	var options := Options.new()
	options.seconds = 10
	options.weather = "clear"
	options.data_directory = OS.get_user_data_dir().path_join("app-tests/short")
	OS.execute("rm", ["-rf", options.data_directory])
	var app := App.new(options)
	app.start(1, 1)
	same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS] as Array[int], "no garden event")
	same(app.garden.plants().size(), 0, "nothing kept")
	check(not DirAccess.dir_exists_absolute(options.data_directory), "the real garden is never touched")


func test_plants_are_kept_with_their_season_and_weather() -> void:
	# A seed whose weather changes part-way, so the plant must be kept with
	# the weather it ended in, not the one it started in.
	for plant_seed in range(1, 100):
		var probe := Weather.new(-1)
		probe.begin(plant_seed, 1)
		var start := probe.kind()
		probe.set_progress(1.0)
		if probe.kind() == start:
			continue
		var app := _app(60, "season")
		app.options.date = {"year": 2026, "month": 1, "day": 10}
		app.weather = Weather.new(-1)
		app.start(1, plant_seed)
		for k in 60:
			app.advance(1000)
		var plant := app.garden.plants()[0]
		same(plant.season, "winter", "season from the pinned date")
		same(plant.weather, Weather.KIND_NAMES[probe.kind()], "the weather it ended in")
		check(plant.weather != Weather.KIND_NAMES[start], "not the one it started in")
		return
	check(false, "no seed changed the weather")


func test_the_idle_window_has_todays_season() -> void:
	var options := Options.new()
	options.date = {"year": 2026, "month": 12, "day": 31}
	same(App.new(options).weather.season(), Weather.Season.WINTER, "before any session")


func test_events_come_in_groves_order() -> void:
	for plant_seed in range(1, 100):
		var probe := Weather.new(-1)
		probe.begin(plant_seed, 11)
		if not probe.set_progress(1.0):
			continue
		var app := _app(10, "order")
		app.weather = Weather.new(-1)
		same(app.start(1, plant_seed), [App.Event.STATE, App.Event.PROGRESS, App.Event.WEATHER] as Array[int], "start")
		same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS, App.Event.WEATHER, App.Event.GARDEN, App.Event.PLANT_BUILT] as Array[int], "finish")
		return
	check(false, "no seed changed the weather")


func test_a_pinned_date_moves_the_light_to_that_day() -> void:
	var app := _app(60, "pinned-day")
	app.clock = func() -> String: return "2026-06-21T17:30:00"
	app.refresh_light()
	check(app.daylight.sun_up, "June evening is light")
	app.options.date = {"year": 2026, "month": 12, "day": 21}
	app.refresh_light()
	check(not app.daylight.sun_up, "the same hour in December is dark")


func test_the_day_of_the_year_counts_leap_days() -> void:
	var app := _app(60, "leap")
	app.clock = func() -> String: return "2024-12-31T12:00:00"
	same(app._day_of_year(), 366, "2024 is a leap year")
	app.clock = func() -> String: return "2026-12-31T12:00:00"
	same(app._day_of_year(), 365, "2026 is not")
	app.clock = func() -> String: return "2026-03-01T12:00:00"
	same(app._day_of_year(), 60, "the first of March")


func test_changing_weather_is_heard_while_building() -> void:
	# Some seed in a hundred changes the weather part-way; when it does, the
	# window hears of it during the session, not only at the start.
	for plant_seed in range(1, 100):
		var app := _app(25 * 60, "changing")
		app.weather = Weather.new(-1)
		app.start(1, plant_seed)
		var heard := 0
		for k in 1500:
			if App.Event.WEATHER in app.advance(1000):
				heard += 1
		if heard > 0:
			check(heard > 5, "heard in visible steps (%d)" % heard)
			return
	check(false, "no seed changed the weather")


func test_the_light_follows_the_clock_unless_pinned() -> void:
	var app := _app(60, "light")
	app.clock = func() -> String: return "2026-06-21T12:30:00"
	app.refresh_light()
	check(app.daylight.sun_up, "noon in June")
	same(app.refresh_light(), [] as Array[int], "no change, no event")
	app.clock = func() -> String: return "2026-06-21T00:30:00"
	same(app.refresh_light(), [App.Event.LIGHT] as Array[int], "midnight is news")
	check(not app.daylight.sun_up, "dark at midnight")
	app.options.time_minutes = 12 * 60 + 30
	app.refresh_light()
	check(app.daylight.sun_up, "AIRSHIP_TIME pins it to noon")


func test_the_accent_warms_dusk_and_is_news_once() -> void:
	var app := _app(60, "accent")
	app.clock = func() -> String: return "2026-11-06T17:10:00"
	app.refresh_light()
	var before := app.daylight.bottom
	same(app.set_accent(Color("#3060ff")), [App.Event.LIGHT] as Array[int], "a new accent")
	check(app.daylight.bottom != before, "dusk changes colour")
	same(app.set_accent(Color("#3060ff")), [] as Array[int], "the same accent again")


func test_a_rusted_plant_tells_the_desktop_nothing() -> void:
	var app := _app(10, "rusted-quiet")
	app.start(1, 7)
	check(not App.Event.PLANT_BUILT in app.give_up(), "no notice for giving up")


func test_each_built_plant_builds_a_fortieth_of_the_airship() -> void:
	var app := _app(25 * 60, "airship")
	same(app.airship_progress(), 0.0, "an empty garden")
	app.start(1, 1)
	app.advance(25 * 60 * 1000)
	same(app.airship_progress(), 1.0 / 40.0, "one built plant")
	app.start(1, 2)
	app.advance(60_000)
	app.give_up()
	same(app.airship_progress(), 1.0 / 40.0, "a rusted plant adds nothing")
	# One built already, by the session above: 39 more make forty.
	for k in 39:
		var plant := Garden.Plant.new()
		plant.when = "2026-11-14T10:00:00"
		plant.progress = 1.0
		app.garden.record(plant)
	same(app.airship_progress(), 1.0, "exactly forty built plants make a whole airship")
	for k in 6:
		var plant := Garden.Plant.new()
		plant.when = "2026-11-14T10:00:00"
		plant.progress = 1.0
		app.garden.record(plant)
	same(app.airship_progress(), 1.0, "never past a whole airship")

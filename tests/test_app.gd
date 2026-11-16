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


func test_the_break_plants_collects_and_fits() -> void:
	var app := _app(25 * 60, "break")
	same(app.break_step(), App.BreakStep.NONE, "nothing to do in an empty garden")
	same(app.take_break_step(), [] as Array[int], "and nothing happens")
	app.start(app.blueprint(), 1)
	same(app.break_step(), App.BreakStep.NONE, "nothing to do while the arm builds")
	app.advance(25 * 60 * 1000)
	same(app.break_step(), App.BreakStep.PLANT, "first the new plant goes out to the garden")
	check(not app.planted(), "it stands on the planter until then")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "planting says so")
	check(app.planted(), "planted")
	same(app.break_step(), App.BreakStep.NONE, "a new plant has made nothing yet: the break is over")
	app.start(app.blueprint(), 2)
	app.advance(25 * 60 * 1000)
	app.take_break_step()
	same(app.break_step(), App.BreakStep.COLLECT, "the first plant made a part in the second session")
	same(app.airship_progress(), 0.0, "a part made isn't on the ship yet")
	same(app.take_break_step(), [App.Event.BREAK] as Array[int], "collecting says so")
	same(app.break_step(), App.BreakStep.FIT, "then it is fitted")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "fitting changes the airship")
	same(app.airship_progress(), 1.0 / 70.0, "one strut on the ship")
	same(app.garden.fitted(), [0, 0, 1, 0, 0] as Array[int], "the oldest plant made it, a girder-reed")
	same(app.break_step(), App.BreakStep.NONE, "and the break has run out")
	same(app.take_break_step(), [] as Array[int], "nothing more to take")


func test_a_skipped_break_loses_nothing() -> void:
	var app := _app(25 * 60, "skipped")
	for k in 3:
		app.start(app.blueprint(), k + 1)
		app.advance(25 * 60 * 1000)
	same(app.airship_progress(), 0.0, "nothing fitted while the breaks were skipped")
	check(app.planted() == false, "the last plant still on the planter")
	app.take_break_step()
	same(app.break_step(), App.BreakStep.COLLECT, "the parts waited")
	app.take_break_step()
	same(app.break_step(), App.BreakStep.FIT, "collected")
	app.take_break_step()
	same(app.airship_progress(), 3.0 / 70.0, "all three fitted in one go")
	# Another Airship opened on the same garden sees the ship as built.
	var again := App.new(app.options)
	same(again.airship_progress(), 3.0 / 70.0, "what was fitted is kept in the garden file")
	same(again.break_step(), App.BreakStep.NONE, "and nothing is asked for twice")


func test_a_session_given_up_leaves_no_plant_to_plant() -> void:
	var app := _app(25 * 60, "no-plant")
	app.start(app.blueprint(), 1)
	app.advance(60_000)
	app.give_up()
	same(app.break_step(), App.BreakStep.NONE, "a rusted plant isn't planted out")


func test_starting_again_plants_the_plant_left_on_the_planter() -> void:
	var app := _app(25 * 60, "left")
	app.start(app.blueprint(), 1)
	app.advance(25 * 60 * 1000)
	app.start(app.blueprint(), 2)
	check(app.planted(), "the arm needs the planter")


func test_the_next_plant_can_be_chosen_from_those_unlocked() -> void:
	var app := _app(25 * 60, "choose")
	same(app.blueprint(), Parts.Kind.GIRDER_REED, "the most needed until someone chooses")
	same(app.choose(1), [App.Event.BLUEPRINT] as Array[int], "choosing says so")
	same(app.blueprint(), Parts.Kind.SAIL_COTTON, "the next one unlocked")
	app.choose(1)
	same(app.blueprint(), Parts.Kind.GIRDER_REED, "round again: only two to start")
	app.choose(-1)
	same(app.blueprint(), Parts.Kind.SAIL_COTTON, "and back the other way")
	app.start(app.blueprint(), 1)
	same(app.choose(1), [] as Array[int], "not while the arm is building")
	app.advance(25 * 60 * 1000)
	same(app.garden.plants()[0].blueprint, Parts.Kind.SAIL_COTTON, "the chosen plant was built")
	same(app.blueprint(), Parts.Kind.GIRDER_REED, "a built plant clears the choice: the most needed again")
	app.choose(1)
	app.start(app.blueprint(), 2)
	app.advance(60_000)
	app.give_up()
	same(app.blueprint(), Parts.Kind.SAIL_COTTON, "giving up keeps the choice")


func test_a_trial_sessions_plant_stands_on_the_planter_unkept() -> void:
	var options := Options.new()
	options.seconds = 10
	var app := App.new(options)
	app.start(2, 1)
	app.advance(10_000)
	same(app.session.state(), Session.State.BUILT, "built")
	check(app.on_planter(), "the finished plant stands on the planter")
	same(app.break_step(), App.BreakStep.NONE, "but it isn't kept, so there is nothing to plant")
	app.start(2, 2)
	check(not app.on_planter(), "until the arm starts again")


func test_blueprints_unlock_by_parts_fitted_and_parts_are_asked_for_again() -> void:
	var app := _app(25 * 60, "fitted-unlocks")
	for k in 3:
		app.start(app.blueprint(), k + 1)
		app.advance(25 * 60 * 1000)
	check(app.on_planter(), "the last plant stands on the planter")
	app.choose(1)
	app.choose(1)
	check(app.blueprint() in [Parts.Kind.GIRDER_REED, Parts.Kind.SAIL_COTTON], "parts made but not fitted unlock nothing")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "plant")
	check(not app.on_planter(), "the planter is empty")
	same(app.take_break_step(), [App.Event.BREAK] as Array[int], "collect")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "fit")
	same(Parts.unlocked(app.airship_progress()).size(), 4, "the first parts on the ship unlock two more")
	app.start(app.blueprint(), 9)
	app.advance(25 * 60 * 1000)
	app.take_break_step()
	same(app.break_step(), App.BreakStep.COLLECT, "another session, more parts to collect")


func test_the_break_scrapes_rust_after_a_completed_session() -> void:
	var app := _app(25 * 60, "rust")
	app.start(Parts.Kind.GIRDER_REED, 9)
	app.advance(25 * 60 * 1000)
	app.take_break_step()
	app.start(Parts.Kind.SAIL_COTTON, 1)
	app.advance(60_000)
	app.give_up()
	same(app.break_step(), App.BreakStep.NONE, "giving up earns no scrape, whatever was built before")
	app.start(Parts.Kind.GIRDER_REED, 2)
	app.advance(25 * 60 * 1000)
	same(app.break_step(), App.BreakStep.PLANT, "first the new plant")
	app.take_break_step()
	same(app.break_step(), App.BreakStep.SCRAPE, "then the rust: a session was completed since")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "scraping changes the garden")
	same(app.garden.plants()[1].scraped, 2, "marked with the sessions completed by then")
	same(app.break_step(), App.BreakStep.COLLECT, "then the parts: the first reed made one")
	app.start(Parts.Kind.GIRDER_REED, 3)
	app.advance(25 * 60 * 1000)
	same(Parts.made(app.garden.plants()), [0, 0, 3, 1, 0] as Array[int], "the scraped plant made its part in the next session")
	var again := App.new(app.options)
	same(again.garden.plants()[2].scraped, 2, "kept in the garden file")


func test_a_finished_airship_is_launched_to_the_next_valley() -> void:
	var app := _app(25 * 60, "launch")
	var sessions := 0
	while app.airship_progress() < 1.0 and sessions < 60:
		app.start(app.blueprint(), sessions + 1)
		app.advance(25 * 60 * 1000)
		sessions += 1
		while app.break_step() != App.BreakStep.NONE and app.break_step() != App.BreakStep.LAUNCH:
			app.take_break_step()
	check(sessions >= 12 and sessions <= 20, "a ship built in %d sessions, breaks taken" % sessions)
	same(app.break_step(), App.BreakStep.LAUNCH, "every part fitted: launch")
	var built := app.garden.plants().size()
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN, App.Event.LAUNCHED] as Array[int], "launching says so")
	same(app.garden.valley(), 1, "the next valley")
	same(app.airship_progress(), 0.0, "a new airship, nothing fitted")
	same(app.break_step(), App.BreakStep.NONE, "and nothing more to do")
	same(app.garden.plants().size(), built, "the old garden is kept as history")
	same(app.garden.valley_plants().size(), 0, "the new garden is empty")
	same(app.blueprint(), Parts.Kind.GIRDER_REED, "the blueprints start over")
	app.start(app.blueprint(), 99)
	app.advance(25 * 60 * 1000)
	same(app.garden.valley_plants().size(), 1, "the first plant of the new valley")
	same(app.garden.plants()[0].valley, 1, "which it remembers")
	app.take_break_step()
	same(app.break_step(), App.BreakStep.NONE, "the old valley's plants make nothing here")
	var again := App.new(app.options)
	same(again.garden.valley(), 1, "kept in the garden file")
	same(again.airship_progress(), 0.0, "with the new airship as it stands")


func test_the_night_train_trades_in_the_break() -> void:
	var app := _app(25 * 60, "trade")
	var sessions := 0
	# Gear-flowers only: cogs made fast, and nothing makes a strut.
	while app.break_step() != App.BreakStep.TRADE and sessions < 12:
		app.start(Parts.Kind.GEAR_FLOWER, sessions + 1)
		check(app.trade() == null, "no trade is offered while the arm builds")
		app.advance(25 * 60 * 1000)
		sessions += 1
		while app.break_step() != App.BreakStep.NONE and app.break_step() != App.BreakStep.TRADE:
			app.take_break_step()
	same(sessions, 5, "the train calls after the fifth session, its offer last")
	same(app.garden.fitted()[Parts.Kind.GEAR_FLOWER], 10, "after the cogs are fitted")
	same(app.trade().gives, Parts.Kind.GEAR_FLOWER, "the train takes cogs")
	same(app.trade().brings, Parts.Kind.GIRDER_REED, "and brings a strut")
	same(app.take_break_step(), [App.Event.BREAK, App.Event.GARDEN] as Array[int], "trading says so")
	same(app.garden.given(), [3] as Array[int], "three cogs given")
	same(app.garden.brought(), [0, 0, 1] as Array[int], "one strut brought")
	same(app.break_step(), App.BreakStep.FIT, "the strut is ready to fit")
	app.take_break_step()
	same(app.garden.fitted()[Parts.Kind.GIRDER_REED], 1, "the strut is on the airship")
	same(app.garden.fitted()[Parts.Kind.GEAR_FLOWER], 10, "and no cog came off it")
	same(app.break_step(), App.BreakStep.NONE, "the break is done")
	var again := App.new(app.options)
	same(again.break_step(), App.BreakStep.NONE, "a new start doesn't trade again")
	# The cogs given are made up before any more reach the ship.
	app.start(Parts.Kind.GEAR_FLOWER, 6)
	app.advance(25 * 60 * 1000)
	app.take_break_step()
	same(app.break_step(), App.BreakStep.COLLECT, "15 cogs made, 12 to hand: two more for the ship")
	app.take_break_step()
	app.take_break_step()
	same(app.garden.fitted()[Parts.Kind.GEAR_FLOWER], 12, "fitted")


func _session(app: App, n: int, give_up := false) -> void:
	app.start(Parts.Kind.GEAR_FLOWER, n)
	if give_up:
		app.advance(60 * 1000)
		app.give_up()
	else:
		app.advance(25 * 60 * 1000)
	while app.break_step() != App.BreakStep.NONE and app.break_step() != App.BreakStep.TRADE:
		app.take_break_step()


func test_a_trade_left_is_gone_when_the_next_session_starts() -> void:
	var app := _app(25 * 60, "trade-left")
	for n in 5:
		_session(app, n + 1)
	same(app.break_step(), App.BreakStep.TRADE, "the train calls after the fifth session")
	same(App.new(app.options).break_step(), App.BreakStep.TRADE, "and is still there after a new start")
	_session(app, 6, true)
	same(app.break_step(), App.BreakStep.NONE, "a session started, even one given up, sends it on")
	same(App.new(app.options).break_step(), App.BreakStep.NONE, "for good")
	for n in 4:
		_session(app, n + 7)
		same(app.break_step(), App.BreakStep.NONE, "no train until the tenth")
	_session(app, 11)
	same(app.break_step(), App.BreakStep.TRADE, "it calls again after the tenth")
	app.take_break_step()
	app.take_break_step()
	same(app.garden.brought(), [0, 0, 1] as Array[int], "one trade")
	same(app.garden.traded_at(), 10, "marked")
	same(app.break_step(), App.BreakStep.NONE, "and no second for the offer that was left")


func test_the_new_valley_has_its_own_visits() -> void:
	var app := _app(25 * 60, "trade-valley")
	for n in 5:
		_session(app, n + 1)
	app.take_break_step()
	same(app.garden.traded_at(), 5, "a trade in the first valley")
	app.garden.launch()
	for n in 5:
		_session(app, n + 6)
	same(app.break_step(), App.BreakStep.TRADE, "the train calls after the new valley's fifth session")


func test_commissions_follow_the_valley() -> void:
	var app := _app(25 * 60, "commissions")
	for n in 4:
		_session(app, n + 1)
	check(app.commissions().open == null, "no commission after four sessions")
	_session(app, 5)
	check(app.commissions().open != null, "one comes with the fifth")
	app.garden.launch()
	check(app.commissions().open == null, "a new valley starts without one")
	same(app.commissions().met, 0, "and without pennants")


func test_the_visiting_airship_stays_for_the_break() -> void:
	var app := _app(25 * 60, "visitor")
	for n in 4:
		_session(app, n + 1)
	same(app.visitor(), -1, "no visitor before the first commission")
	_session(app, 5)
	same(app.visitor(), 0, "the first commission's airship is moored")
	same(App.new(app.options).visitor(), 0, "still there after a new start")
	app.start(Parts.Kind.GEAR_FLOWER, 6)
	same(app.visitor(), -1, "gone once the next session starts")
	app.advance(60 * 1000)
	app.give_up()
	same(app.visitor(), -1, "and not back when that one is given up")

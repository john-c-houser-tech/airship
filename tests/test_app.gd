extends TestCase
## How the app turns what a session did into events for the window.


func _app(seconds: int, name := "app") -> App:
	var folder := OS.get_user_data_dir().path_join("app-tests").path_join(name)
	OS.execute("rm", ["-rf", folder])
	var options := Options.new()
	options.seconds = seconds
	options.garden_path = folder.path_join("garden.json")
	var app := App.new(options)
	app.clock = func() -> String: return "2026-11-14T10:00:00"
	return app


func test_the_session_length_comes_from_the_options() -> void:
	same(_app(30).session.seconds(), 30, "seconds")


func test_starting_says_the_state_and_progress_changed() -> void:
	var app := _app(10)
	same(app.start(1, 7), [App.Event.STATE, App.Event.PROGRESS] as Array[int], "events")


func test_a_tick_too_small_to_see_says_nothing() -> void:
	var app := _app(25 * 60)
	app.start(1, 7)
	same(app.advance(50), [] as Array[int], "events")


func test_finishing_says_both() -> void:
	var app := _app(10)
	app.start(1, 7)
	same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS, App.Event.GARDEN] as Array[int], "events")
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
	var app := App.new(options)
	app.start(1, 1)
	same(app.advance(25 * 60 * 1000), [App.Event.STATE, App.Event.PROGRESS, App.Event.GARDEN, App.Event.GARDEN_PROBLEM] as Array[int], "first")
	same(app.garden.problem(), Garden.Problem.NO_FOLDER, "problem")
	same(app.garden_change, Garden.Change.INSERTED, "shown, not saved")
	app.start(1, 2)
	same(app.advance(25 * 60 * 1000), [App.Event.STATE, App.Event.PROGRESS, App.Event.GARDEN] as Array[int], "second")


func test_a_shortened_session_is_not_kept_without_a_garden_of_its_own() -> void:
	var options := Options.new()
	options.seconds = 10
	options.data_directory = OS.get_user_data_dir().path_join("app-tests/short")
	OS.execute("rm", ["-rf", options.data_directory])
	var app := App.new(options)
	app.start(1, 1)
	same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS] as Array[int], "no garden event")
	same(app.garden.plants().size(), 0, "nothing kept")
	check(not DirAccess.dir_exists_absolute(options.data_directory), "the real garden is never touched")

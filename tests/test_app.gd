extends TestCase
## How the app turns what a session did into events for the window.


func _app(seconds: int) -> App:
	var options := Options.new()
	options.seconds = seconds
	return App.new(options)


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
	same(app.advance(10_000), [App.Event.STATE, App.Event.PROGRESS] as Array[int], "events")
	same(app.session.state(), Session.State.BUILT, "state")


func test_giving_up_says_the_state_changed() -> void:
	var app := _app(10)
	app.start(1, 7)
	same(app.give_up(), [App.Event.STATE] as Array[int], "events")
	same(app.give_up(), [] as Array[int], "a second give-up")

class_name App
extends RefCounted
## Airship's state and the rules that tie its parts together. The window
## calls in (a key pressed, time passed) and hears back a list of events
## saying what changed; App itself runs no timers and draws nothing.
##
## It grows with milestone 4: the garden, the light and weather, languages
## and sounds join it in later PRs.

## Something that changed, for the window to hear about.
enum Event {
	## A session started, finished or was given up.
	STATE,
	## The countdown moved on a second, or the plant grew enough to show.
	PROGRESS,
	## The garden's plants changed: `garden_change` says how.
	GARDEN,
	## Whether the garden can be read and saved changed.
	GARDEN_PROBLEM,
}

var options: Options
var session: Session
var garden: Garden
## How the garden's plants last changed.
var garden_change := Garden.Change.RESET
## Local time as YYYY-MM-DDTHH:MM:SS, for when a plant was finished; tests
## replace it.
var clock := func() -> String: return Time.get_datetime_string_from_system(false, false)


func _init(options_: Options) -> void:
	options = options_
	session = Session.new(options.seconds)
	var path := options.garden_path
	if path.is_empty():
		path = Garden.default_path(options.data_directory)
	garden = Garden.new(path)


## Starts building the plant of `blueprint` and `plant_seed`, unless a
## session is under way.
func start(blueprint: int, plant_seed: int) -> Array[int]:
	return _session_changed(session.start(blueprint, plant_seed))


## Giving up early leaves the half-built plant to rust.
func give_up() -> Array[int]:
	return _session_changed(session.give_up())


## Moves the clock on by real time that has passed.
func advance(milliseconds: int) -> Array[int]:
	return _session_changed(session.advance(milliseconds))


func _session_changed(changes: Session.Changes) -> Array[int]:
	var events: Array[int] = []
	if changes.state:
		events.append(Event.STATE)
	if changes.progress:
		events.append(Event.PROGRESS)
	if changes.state and session.state() in [Session.State.BUILT, Session.State.RUSTED]:
		# A shortened test session (AIRSHIP_SECONDS) isn't kept unless a
		# garden is given, so trying Airship out never adds make-believe
		# plants to the real garden.
		if session.seconds() == Options.SESSION_SECONDS or not options.garden_path.is_empty():
			events.append_array(_record())
	return events


## Keeps the plant a session ended with: built, and earning the session's
## minutes, or rusted at the size it reached, earning none.
func _record() -> Array[int]:
	var plant := Garden.Plant.new()
	var built := session.state() == Session.State.BUILT
	plant.blueprint = session.blueprint()
	plant.plant_seed = session.plant_seed()
	plant.outcome = Garden.Outcome.BUILT if built else Garden.Outcome.RUSTED
	plant.progress = 1.0 if built else session.progress()
	plant.minutes = floori(session.seconds() / 60.0) if built else 0
	plant.when = clock.call() as String
	# The season and weather join in with the light and weather (4c).
	var problem_before := garden.problem()
	garden_change = garden.record(plant)
	var events: Array[int] = [Event.GARDEN]
	if garden.problem() != problem_before:
		events.append(Event.GARDEN_PROBLEM)
	return events

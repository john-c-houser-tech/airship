class_name App
extends RefCounted
## Airship's state and the rules that tie its parts together. The window
## calls in (a key pressed, time passed) and hears back a list of events
## saying what changed; App itself runs no timers and draws nothing.
##
## It grows with milestone 4: languages and sounds join it in later PRs.

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
	## The weather or the season changed enough to see.
	WEATHER,
	## The light moved on: the sun, the moon, the sky's colours.
	LIGHT,
}

## The desktop's accent until the theme says otherwise (4d), as in Grove.
const DEFAULT_ACCENT := Color("#ffd60a")

var options: Options
var session: Session
var garden: Garden
var weather: Weather
var daylight: Daylight
## The colour dusk is warmed toward.
var accent := DEFAULT_ACCENT
## How the garden's plants last changed.
var garden_change := Garden.Change.RESET
## Local time as YYYY-MM-DDTHH:MM:SS: when a plant was finished, and, unless
## AIRSHIP_DATE or AIRSHIP_TIME pin them, the season and the light. Tests
## replace it.
var clock := func() -> String: return Time.get_datetime_string_from_system(false, false)


func _init(options_: Options) -> void:
	options = options_
	session = Session.new(options.seconds)
	var path := options.garden_path
	if path.is_empty():
		path = Garden.default_path(options.data_directory)
	garden = Garden.new(path)
	weather = Weather.new(Weather.kind_named(options.weather))
	# The idle window has weather too, in today's season: seeded by the date,
	# so the core stays a function of its inputs.
	var today := _now()
	weather.begin(int(today["year"]) * 1000 + _day_of_year(), _month())
	daylight = Daylight.at(_day_of_year(), _hour(), accent)


## Starts building the plant of `blueprint` and `plant_seed`, unless a
## session is under way. The seed rolls the session's weather too.
func start(blueprint: int, plant_seed: int) -> Array[int]:
	var changes := session.start(blueprint, plant_seed)
	if changes.state:
		weather.begin(plant_seed, _month())
	return _session_changed(changes, changes.state)


## Giving up early leaves the half-built plant to rust.
func give_up() -> Array[int]:
	return _session_changed(session.give_up())


## Moves the clock on by real time that has passed.
func advance(milliseconds: int) -> Array[int]:
	var changes := session.advance(milliseconds)
	# The weather moves before the plant is kept, so it is kept with the
	# weather it ended in.
	var moved := changes.progress and weather.set_progress(session.progress())
	return _session_changed(changes, moved)


## Reads the clock again for the light (the window does this every minute or
## so), unless AIRSHIP_TIME and AIRSHIP_DATE pin it.
func refresh_light() -> Array[int]:
	var next := Daylight.at(_day_of_year(), _hour(), accent)
	if next.equals(daylight):
		return []
	daylight = next
	return [Event.LIGHT]


## The events for what a call changed, in Grove's order: the session, the
## weather, then the garden.
func _session_changed(changes: Session.Changes, weather_moved := false) -> Array[int]:
	var events: Array[int] = []
	if changes.state:
		events.append(Event.STATE)
	if changes.progress:
		events.append(Event.PROGRESS)
	if weather_moved:
		events.append(Event.WEATHER)
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
	plant.season = Weather.SEASON_NAMES[weather.season()]
	plant.weather = Weather.KIND_NAMES[weather.kind()]
	var problem_before := garden.problem()
	garden_change = garden.record(plant)
	var events: Array[int] = [Event.GARDEN]
	if garden.problem() != problem_before:
		events.append(Event.GARDEN_PROBLEM)
	return events


## The clock's date and time as numbers, with AIRSHIP_DATE and AIRSHIP_TIME
## put in place of the real ones.
func _now() -> Dictionary:
	var text := clock.call() as String
	var now := {
		"year": text.substr(0, 4).to_int(), "month": text.substr(5, 2).to_int(), "day": text.substr(8, 2).to_int(),
		"minutes": text.substr(11, 2).to_int() * 60 + text.substr(14, 2).to_int(),
	}
	if not options.date.is_empty():
		now.merge(options.date, true)
	if options.time_minutes >= 0:
		now["minutes"] = options.time_minutes
	return now


func _month() -> int:
	return int(_now()["month"])


func _hour() -> float:
	return int(_now()["minutes"]) / 60.0


## 1 for the first of January.
func _day_of_year() -> int:
	var now := _now()
	var day := int(now["day"])
	for month in range(1, int(now["month"])):
		day += Options.days_in(int(now["year"]), month)
	return day

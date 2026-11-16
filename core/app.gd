class_name App
extends RefCounted
## Airship's state and the rules that tie its parts together. The window
## calls in (a key pressed, time passed) and hears back a list of events
## saying what changed; App itself runs no timers and draws nothing.
##

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
	## The light moved on: the sun, the moon, the sky's colours, or the
	## accent they're warmed toward.
	LIGHT,
	## A plant was built to the end and kept, which the desktop should be
	## told.
	PLANT_BUILT,
	## The language changed, so everything said is said again.
	LANGUAGE,
	## A distant sound is due now: `sound` says which.
	SOUND,
	## The session's sounds are over: one still playing fades out.
	SOUNDS_ENDED,
	## The sounds were muted or unmuted.
	MUTED,
	## A step of the break was taken: `break_step()` says what comes next.
	BREAK,
	## The airship was launched: on to the next valley.
	LAUNCHED,
	## Another plant was chosen to build next: `blueprint()` says which.
	## (A plant built to the end changes it too, with GARDEN.)
	BLUEPRINT,
}

## The desktop's accent until the theme says otherwise (4d), as in Grove.
const DEFAULT_ACCENT := Color("#ffd60a")

var options: Options
var session: Session
var garden: Garden
var weather: Weather
var daylight: Daylight
## The words in the language Omarchy (or AIRSHIP_LANGUAGE) picked.
var catalog: Catalog
## The sound last due (Sounds.Kind).
var sound := Sounds.Kind.TRAIN
var muted := false
# This session's sounds, or null when none are to be heard.
var _sound_plan: Sounds.Plan
## The colour dusk is warmed toward.
var accent := DEFAULT_ACCENT
## How the garden's plants last changed.
var garden_change := Garden.Change.RESET
# The blueprint chosen for the next session, or -1 for the one most needed.
# A plant built to the end clears it: the garden's needs have moved on.
var _chosen := -1
# The plant just built still stands on the planter, waiting to be planted
# out. Not saved: a new session, or a new start, plants it.
var _to_plant := false
# A finished plant stands on the planter: the one to plant, or a trial
# session's, which is never kept and stands there until the next session.
var _on_planter := false
# The parts picked up in this run (from the garden's plants, or brought
# by the night train), by kind: at least those fitted. Not saved: after a new start they are picked again.
var _collected: Array[int] = []
# A session has started since the night train last called, so it has moved
# on: for a session the garden doesn't keep (a trial run), which leaves no
# plant to tell by.
var _train_left := false

## What the break after a session asks for, one thing at a time.
enum BreakStep {
	## Nothing left to do.
	NONE,
	## Plant the new plant out in the garden.
	PLANT,
	## Scrape the rust off a plant that seized.
	SCRAPE,
	## Pick the parts the garden's plants have made.
	COLLECT,
	## Fit the picked parts to the airship.
	FIT,
	## Trade parts with the night train for one the garden is slow to make:
	## an offer, which can be left.
	TRADE,
	## Launch the finished airship over the pass.
	LAUNCH,
}
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
	catalog = Catalog.new(options.language if not options.language.is_empty() else "en")
	muted = Settings.muted(options.settings_file)
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
		# A plant still on the planter goes out to the garden: the arm needs it.
		_to_plant = false
		_on_planter = false
		_train_left = true
		weather.begin(plant_seed, _month())
		# Its own numbers from the seed, so the sounds don't follow the weather.
		_sound_plan = Sounds.roll(Random.new(plant_seed ^ 0x5_0D5), options.sound_test,
			Sounds.period_of(daylight), session.seconds())
	return _session_changed(changes, changes.state)


## Giving up early leaves the half-built plant to rust.
func give_up() -> Array[int]:
	return _session_changed(session.give_up())


## Moves the clock on by real time that has passed.
func advance(milliseconds: int) -> Array[int]:
	var changes := session.advance(milliseconds)
	var events: Array[int] = []
	# A sound due by now starts, if the sky still suits it.
	if _sound_plan != null and session.state() == Session.State.BUILDING:
		var due := _sound_plan.due(session.elapsed_seconds(), Sounds.period_of(daylight),
			Sounds.flight_weather(weather.now()))
		if due >= 0:
			sound = due as Sounds.Kind
			events.append(Event.SOUND)
	# The weather moves before the plant is kept, so it is kept with the
	# weather it ended in.
	var moved := changes.progress and weather.set_progress(session.progress())
	events.append_array(_session_changed(changes, moved))
	return events


## Mutes or unmutes the sounds, and remembers it for the next run.
func set_muted(value: bool) -> Array[int]:
	if value == muted:
		return []
	muted = value
	Settings.remember_muted(options.settings_file, muted)
	return [Event.MUTED]


## How far the airship in the hangar is built, 0 to 1, from the parts
## fitted to it (core/parts.gd).
func airship_progress() -> float:
	return Parts.airship_built(garden.fitted())


## The next thing the break asks for; NONE while the arm builds and once
## everything is done. Each step is short and they run out, so the break
## can't turn into the game; skipping them loses nothing, they wait: all
## but the night train's offer, which goes when the next session starts.
func break_step() -> BreakStep:
	if session.state() == Session.State.BUILDING:
		return BreakStep.NONE
	if _to_plant:
		return BreakStep.PLANT
	if Parts.to_scrape(garden.valley_plants()) >= 0:
		return BreakStep.SCRAPE
	var ready := Parts.waiting(_have(), garden.fitted())
	var picked := Parts.waiting(_picked(), garden.fitted())
	for kind in Parts.KINDS:
		if ready[kind] > picked[kind]:
			return BreakStep.COLLECT
	for kind in Parts.KINDS:
		if picked[kind] > 0:
			return BreakStep.FIT
	# Last, and only an offer: it can be left, and the train moves on when
	# the next session starts.
	if trade() != null:
		return BreakStep.TRADE
	if airship_progress() >= 1.0:
		return BreakStep.LAUNCH
	return BreakStep.NONE


## Takes the break's next step, if there is one.
func take_break_step() -> Array[int]:
	match break_step():
		BreakStep.PLANT:
			_to_plant = false
			_on_planter = false
			return [Event.BREAK, Event.GARDEN]
		BreakStep.SCRAPE:
			var before := garden.problem()
			var plants := garden.valley_plants()
			garden.scrape(plants[Parts.to_scrape(plants)], Parts.sessions(plants))
			garden_change = Garden.Change.RESET
			var scraped: Array[int] = [Event.BREAK, Event.GARDEN]
			if garden.problem() != before:
				scraped.append(Event.GARDEN_PROBLEM)
			return scraped
		BreakStep.COLLECT:
			_collected = _have()
			return [Event.BREAK]
		BreakStep.TRADE:
			var before := garden.problem()
			var offer := trade()
			garden.trade(offer.gives, Parts.TRADE_GIVES, offer.brings, Parts.sessions(garden.valley_plants()))
			garden_change = Garden.Change.RESET
			# The train's part is handed over: picked, ready to fit.
			_collected = _have()
			var traded: Array[int] = [Event.BREAK, Event.GARDEN]
			if garden.problem() != before:
				traded.append(Event.GARDEN_PROBLEM)
			return traded
		BreakStep.FIT:
			var problem_before := garden.problem()
			var fitted := garden.fitted()
			var picked := Parts.waiting(_picked(), fitted)
			var total: Array[int] = []
			for kind in Parts.KINDS:
				total.append((fitted[kind] if kind < fitted.size() else 0) + picked[kind])
			garden.fit(total)
			# Fitting reads the file again, another Airship's plants and all.
			garden_change = Garden.Change.RESET
			var events: Array[int] = [Event.BREAK, Event.GARDEN]
			if garden.problem() != problem_before:
				events.append(Event.GARDEN_PROBLEM)
			return events
		BreakStep.LAUNCH:
			var before := garden.problem()
			garden.launch()
			garden_change = Garden.Change.RESET
			# A new valley, a new garden: nothing picked, nothing chosen.
			_collected = []
			_chosen = -1
			var launched: Array[int] = [Event.BREAK, Event.GARDEN, Event.LAUNCHED]
			if garden.problem() != before:
				launched.append(Event.GARDEN_PROBLEM)
			return launched
	return []


## Whether the plant just built has been planted out (or there is none):
## whether the garden shows every plant it holds.
func planted() -> bool:
	return not _to_plant


## Whether a finished plant stands on the planter.
func on_planter() -> bool:
	return _on_planter


# The parts picked so far, by kind, a count for every kind: never more
# than the garden has made, should its plants have changed since.
func _picked() -> Array[int]:
	var parts := _have()
	var picked: Array[int] = []
	for kind in Parts.KINDS:
		picked.append(mini(_collected[kind], parts[kind]) if kind < _collected.size() else 0)
	return picked


# The parts to hand, by kind: made by the garden, less those given to the
# night train, and those it brought.
func _have() -> Array[int]:
	return Parts.have(Parts.made(garden.valley_plants()), garden.given(), garden.brought())


## The trade the night train offers in this break, or null.
func trade() -> Parts.Trade:
	if session.state() == Session.State.BUILDING or _train_left:
		return null
	return Parts.trade(garden.valley_plants(), garden.given(), garden.brought(), garden.fitted(), garden.traded_at())


## The blueprint to build next when nobody chooses: the plant whose parts
## the airship is shortest of.
func next_blueprint() -> int:
	return Parts.most_needed(garden.valley_plants(), Parts.unlocked(airship_progress()), garden.given(), garden.brought())


## The blueprint the next session builds: the one chosen, or the one most
## needed until someone chooses.
func blueprint() -> int:
	if _chosen in Parts.unlocked(airship_progress()):
		return _chosen
	return next_blueprint()


## Chooses the next (`step` 1) or the one before (-1) of the unlocked
## blueprints, round and round. Not while the arm is building.
func choose(step: int) -> Array[int]:
	if session.state() == Session.State.BUILDING:
		return []
	var open := Parts.unlocked(airship_progress())
	_chosen = open[posmod(open.find(blueprint()) + step, open.size())]
	return [Event.BLUEPRINT]


## How loud a sound is played, 0 to 1.
func volume(kind: Sounds.Kind) -> float:
	return Sounds.VOLUMES[kind] * options.sound_volume


## Takes the desktop's language, unless AIRSHIP_LANGUAGE pins one.
func set_language(code: String) -> Array[int]:
	if not options.language.is_empty() or code == catalog.code():
		return []
	catalog = Catalog.new(code)
	return [Event.LANGUAGE]


## The translation of an English text in the current language.
func say(source: String) -> String:
	return catalog.translate(source)


## Takes the desktop's accent, which warms dusk.
func set_accent(colour: Color) -> Array[int]:
	if colour == accent:
		return []
	accent = colour
	daylight = Daylight.at(_day_of_year(), _hour(), accent)
	return [Event.LIGHT]


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
	if changes.state and session.state() != Session.State.BUILDING and _sound_plan != null:
		# Given up or finished: a sound under way fades, any to come are dropped.
		_sound_plan = null
		events.append(Event.SOUNDS_ENDED)
	if changes.state and session.state() == Session.State.BUILT:
		_on_planter = true
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
	plant.valley = garden.valley()
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
	if built:
		# A session built to the end, and kept: the train may call.
		_train_left = false
		events.append(Event.PLANT_BUILT)
		_chosen = -1
		_to_plant = true
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

class_name Sounds
extends RefCounted
## Faint sounds from far away while the arm builds. At night a steam train
## passes the crossing, one to three times in a session; by day an airship
## flies over now and then. This file decides which and when; the sounds
## themselves are made ahead of time (tools/make_sounds.gd) and played by the
## window. Grove's sounds.rs is the spec.

## A distant sound.
enum Kind { TRAIN, AIRSHIP }
## The part of the day, as far as the sounds care. Dawn and dusk are
## BETWEEN, when nothing is heard.
enum Period { DAY, NIGHT, BETWEEN }

const NAMES: Array[String] = ["train", "airship"]
## How long each sound lasts, in seconds (the files in sounds/).
const SECONDS: Array[float] = [44.0, 34.0]
## How loud each is played, 0 to 1, before AIRSHIP_SOUND_VOLUME.
const VOLUMES: Array[float] = [0.45, 0.4]
const FILES: Array[String] = ["res://sounds/train.wav", "res://sounds/airship.wav"]


## The kind of that name, or -1.
static func named(name: String) -> int:
	return NAMES.find(name)


## The period under a sky: day in good light, night in the dark.
static func period_of(daylight: Daylight) -> Period:
	if daylight.sun_up and daylight.ambient > 0.6:
		return Period.DAY
	if not daylight.sun_up and daylight.ambient < 0.35:
		return Period.NIGHT
	return Period.BETWEEN


## How many times a sound happens in one session: a train 1 to 3 times, an
## airship 0 to 2.
static func count(kind: Kind, random: Random) -> int:
	var r := random.unit()
	if kind == Kind.TRAIN:
		return 1 if r < 0.45 else (2 if r < 0.8 else 3)
	return 0 if r < 0.35 else (1 if r < 0.8 else 2)


## When sounds begin, in seconds from the start of a session: `wanted` of
## them if they fit, always inside the session and well apart; fewer if they
## don't fit.
static func times(random: Random, wanted: int, session_seconds: float, sound_seconds: float) -> Array[float]:
	# Nothing right at the start or the end, and never two close together.
	var margin := 20.0
	var gap := sound_seconds + 90.0
	var latest := session_seconds - sound_seconds - margin
	for n in range(wanted, 0, -1):
		if latest < margin + (n - 1) * gap:
			continue
		for attempt in 200:
			var found: Array[float] = []
			for k in n:
				found.append(margin + random.unit() * (latest - margin))
			found.sort()
			var apart := true
			for k in range(1, n):
				apart = apart and found[k] - found[k - 1] >= gap
			if apart:
				return found
	return []


## The sounds of one session: what, and when the ones still to come begin.
class Plan:
	var kind := Kind.TRAIN
	## Seconds from the start of the session, soonest first.
	var times: Array[float] = []
	## Asked for by name (AIRSHIP_SOUND_TEST), so it happens whatever the
	## hour and the weather.
	var forced := false

	## The sound to start now, `elapsed` seconds in, if one is due and the
	## sky still suits it: night may have ended, or the weather turned. A
	## sound that is due is used up either way. -1 if none.
	func due(elapsed: float, period: Period, flight_weather: bool) -> int:
		if times.is_empty() or times[0] > elapsed:
			return -1
		times.remove_at(0)
		var suits := period == Period.NIGHT if kind == Kind.TRAIN else (period == Period.DAY and flight_weather)
		return kind if forced or suits else -1


## The plan for a session of `session_seconds` starting in `period`, or null
## when nothing is to be heard. `forced` (a kind, or -1) makes that sound
## happen three seconds in whatever the hour, for trying it out.
static func roll(random: Random, forced: int, period: Period, session_seconds: float) -> Plan:
	var plan := Plan.new()
	if forced >= 0:
		plan.kind = forced as Kind
		plan.times = [3.0]
		plan.forced = true
		return plan
	if period == Period.BETWEEN:
		return null
	plan.kind = Kind.TRAIN if period == Period.NIGHT else Kind.AIRSHIP
	plan.times = times(random, count(plan.kind, random), session_seconds, SECONDS[plan.kind])
	return null if plan.times.is_empty() else plan


## Whether an airship can be seen and heard: not in rain, snow or fog.
static func flight_weather(now: Weather.Conditions) -> bool:
	return now.rain < 0.25 and now.snow < 0.25 and now.fog < 0.35

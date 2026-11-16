class_name Commissions
extends RefCounted
## Commissions: now and then a visiting airship asks for plants built a
## certain way, such as two pipe-vines built under a clear sky. There is
## no deadline, and only focus meets one: each plant built to the end
## since it was asked, of the kind and in the weather asked for, counts.
## One is open at a time; the first comes with a valley's fifth completed
## session, and the next as soon as the last is met. Each one met wins a
## pennant for that valley's airship, and nothing else: a commission is
## never the faster way to build.
##
## Nothing is saved for them. Which commission is open, how far along it
## is and how many were met all follow from the valley's plants, in the
## order the garden keeps them; what each asks follows from the plant
## whose session brought it. (So what stands can shift in the rare case
## that the order does: a plant this window couldn't save yet goes in
## after one another window saved meanwhile.) The weather a plant counts
## for is the one its session ended in, which is what the garden keeps.
## A commission may ask for a gear-flower or a pipe-vine before the first
## part is fitted and they unlock; it waits, as any does.

## Completed sessions in a valley before its first commission.
const FIRST_AFTER := 5
## The weather a commission may ask for: any (-1), or one that every
## season has. In English; the window translates what it shows.
const WEATHERS: Array[int] = [-1, Weather.Kind.CLEAR, Weather.Kind.CLOUDY, Weather.Kind.RAIN]
const WEATHER_PHRASES: Array[String] = ["in any weather", "under a clear sky", "under cloud", "in the rain"]
## How many plants are asked for in any weather. In a weather asked for
## by name it is two where that weather is the season's usual, else one:
## nobody can choose a session's weather, so the wait is kept short.
const ANY_WEATHER_COUNT := 3
## A weather is asked for only where at least this share of sessions have
## it in the season it is asked, and that share in the season after; and
## two plants only where it is this common.
const LEAST_SHARE := 0.2
const LEAST_SHARE_AFTER := 0.1
const USUAL_SHARE := 0.5


## What a visiting airship asks for.
class Commission:
	## Which commission of the valley this is, from 0.
	var number := 0
	## The plant asked for (Parts.Kind).
	var kind := 0
	## The weather to build it in, as a place in WEATHERS.
	var weather := 0
	## How many are asked for, and how many are built so far.
	var count := 0
	var done := 0


## Where a valley's commissions stand.
class State:
	## The commission open now, or null before the first.
	var open: Commission = null
	## How many were met: the pennants won.
	var met := 0
	## Whether the open commission came with the valley's newest plant: the
	## visiting airship is still here, until the next session starts.
	var fresh := false


## Where the commissions stand for a valley's `plants`, newest first.
static func state(plants: Array[Garden.Plant]) -> State:
	var now := State.new()
	var completed := 0
	for k in range(plants.size() - 1, -1, -1):
		var plant := plants[k]
		if plant.outcome != Garden.Outcome.BUILT:
			continue
		completed += 1
		if now.open == null:
			if completed == FIRST_AFTER:
				now.open = _asked(0, plant)
				now.fresh = k == 0
			continue
		if _meets(plant, now.open):
			now.open.done += 1
			if now.open.done >= now.open.count:
				now.met += 1
				now.open = _asked(now.met, plant)
				now.fresh = k == 0
	return now


## Whether a plant built to the end is one the commission asks for.
static func _meets(plant: Garden.Plant, commission: Commission) -> bool:
	if Parts.kind_of(plant.blueprint) != commission.kind:
		return false
	var wanted := WEATHERS[commission.weather]
	return wanted < 0 or plant.weather == Weather.KIND_NAMES[wanted]


## The share of a season's sessions that have a kind of weather.
static func _share(weather: int, season: int) -> float:
	var total := 0.0
	for w: float in Weather.WEIGHTS[season]:
		total += w
	return float(Weather.WEIGHTS[season][weather]) / total


## Whether a weather comes often enough to ask for in a season: there,
## and not too rarely in the season after (a commission can run on).
static func _common(weather: int, season: int) -> bool:
	return _share(weather, season) >= LEAST_SHARE \
			and _share(weather, (season + 1) % Weather.WEIGHTS.size()) >= LEAST_SHARE_AFTER


## The commission of that number, brought by the session that built `plant`:
## its own numbers from that plant's seed, so it is the same every time.
static func _asked(number: int, plant: Garden.Plant) -> Commission:
	# Apart from the weather and the sounds rolled from the same seed.
	var random := Random.apart(plant.plant_seed, number)
	var commission := Commission.new()
	commission.number = number
	# One of the four quick plants: a kettle-gourd may not be unlocked.
	commission.kind = mini(floori(random.unit() * 4.0), 3)
	commission.weather = mini(floori(random.unit() * WEATHERS.size()), WEATHERS.size() - 1)
	commission.count = ANY_WEATHER_COUNT
	if WEATHERS[commission.weather] >= 0:
		# A weather too rare to wait for, in this season or the next (or in
		# a plant of no known season): cloud, which every season has.
		var season := Weather.SEASON_NAMES.find(plant.season)
		if season < 0 or not _common(WEATHERS[commission.weather], season):
			commission.weather = WEATHERS.find(Weather.Kind.CLOUDY)
		commission.count = 2 if season >= 0 and _share(WEATHERS[commission.weather], season) >= USUAL_SHARE else 1
	return commission

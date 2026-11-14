class_name Weather
extends RefCounted
## The sky's mood, which is invented and never fetched. Each session rolls a
## weather for its start and another for its end, weighted by the season, and
## the arm builds through the change between them.
##
## Grove's weather.rs is the spec. Its rain nudged the plant's growth along;
## Airship's arm follows a timed build plan, so the weather changes the sky
## and nothing else.

## A kind of weather.
enum Kind { CLEAR, CLOUDY, RAIN, FOG, SNOW }
## A season of the year.
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

## The names the garden and the window know them by.
const KIND_NAMES: Array[String] = ["clear", "cloudy", "rain", "fog", "snow"]
const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]

# Weights for clear, cloudy, rain, fog and snow in each season. Summer is
# mostly clear, autumn is the foggy season, and only winter brings snow.
const WEIGHTS: Array[Array] = [
	[3.0, 3.0, 3.0, 1.0, 0.0],
	[6.0, 2.0, 0.7, 0.5, 0.0],
	[2.0, 3.0, 3.0, 2.5, 0.0],
	[1.0, 3.0, 1.5, 2.0, 2.5],
]


## How much of each weather there is, each from 0 to 1.
class Conditions:
	var cloud := 0.0
	var rain := 0.0
	var fog := 0.0
	var snow := 0.0

	func _init(cloud_ := 0.0, rain_ := 0.0, fog_ := 0.0, snow_ := 0.0) -> void:
		cloud = cloud_
		rain = rain_
		fog = fog_
		snow = snow_

	## The dominant weather.
	func kind() -> Kind:
		if fog >= 0.45:
			return Kind.FOG
		if snow >= 0.4:
			return Kind.SNOW
		if rain >= 0.4:
			return Kind.RAIN
		if cloud >= 0.5:
			return Kind.CLOUDY
		return Kind.CLEAR

	## The largest difference in any one amount.
	func distance(other: Conditions) -> float:
		return maxf(maxf(absf(cloud - other.cloud), absf(rain - other.rain)),
			maxf(absf(fog - other.fog), absf(snow - other.snow)))

	func equals(other: Conditions) -> bool:
		return distance(other) == 0.0


## The kind of that name, or -1.
static func kind_named(name: String) -> int:
	return KIND_NAMES.find(name)


## The amounts of a weather once it has fully set in.
static func conditions_of(kind: Kind) -> Conditions:
	match kind:
		Kind.CLOUDY:
			return Conditions.new(0.75, 0.0, 0.0, 0.0)
		Kind.RAIN:
			return Conditions.new(0.95, 0.8, 0.0, 0.0)
		Kind.FOG:
			return Conditions.new(0.15, 0.0, 1.0, 0.0)
		Kind.SNOW:
			return Conditions.new(0.9, 0.0, 0.0, 0.85)
	return Conditions.new()


## The season of a month (1 to 12), by the calendar, in the northern
## hemisphere.
static func season_of_month(month: int) -> Season:
	if month >= 3 and month <= 5:
		return Season.SPRING
	if month >= 6 and month <= 8:
		return Season.SUMMER
	if month >= 9 and month <= 11:
		return Season.AUTUMN
	return Season.WINTER


## Rolls a kind of weather by the season's weights.
static func pick(random: Random, season: Season) -> Kind:
	var weights: Array = WEIGHTS[season]
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := random.unit() * total
	for k in weights.size():
		if roll < float(weights[k]):
			return k as Kind
		roll -= float(weights[k])
	return Kind.CLEAR


var _forced := -1
var _season := Season.SUMMER
var _from := Kind.CLEAR
var _to := Kind.CLEAR
var _now := Conditions.new()


## A kind pins the weather, for screenshots and tests; -1 lets it roll. Until
## `begin` rolls a session's weather, the sky is clear, or as pinned.
func _init(forced: int) -> void:
	_forced = forced
	if forced >= 0:
		_from = forced as Kind
		_to = forced as Kind
	_now = conditions_of(_from)


## The dominant weather right now.
func kind() -> Kind:
	return _now.kind()


## The season of the session's date.
func season() -> Season:
	return _season


## How much of each weather there is now. The amounts move from the session's
## first weather to its second between 30% and 70% of the way through.
func now() -> Conditions:
	return _now


## Rolls the weather for a new session in `month` (1 to 12).
func begin(plant_seed: int, month: int) -> void:
	var random := Random.new(plant_seed)
	_season = season_of_month(month)
	if _forced >= 0:
		_from = _forced as Kind
		_to = _forced as Kind
	else:
		_from = pick(random, _season)
		# About half of all sessions change weather part-way through.
		_to = _from if random.unit() < 0.5 else pick(random, _season)
	_now = _at(0.0)


## Moves the weather through the session (0 to 1) as its progress changes.
## True if the sky changed enough to redraw: the sky changes over minutes, so
## a change is only announced once it has moved enough to see (1% of any
## amount), and once more when it settles.
func set_progress(progress: float) -> bool:
	var at := clampf(progress, 0.0, 1.0)
	var next := _at(at)
	var moved := next.distance(_now)
	var settled := at <= 0.3 or at >= 0.7
	if moved >= 0.01 or (settled and moved > 0.0):
		_now = next
		return true
	return false


## The conditions at a point in the session.
func _at(progress: float) -> Conditions:
	# The change happens in the middle of the session, not at a fixed moment.
	var s := smoothstep(0.3, 0.7, progress)
	var a := conditions_of(_from)
	var b := conditions_of(_to)
	return Conditions.new(lerpf(a.cloud, b.cloud, s), lerpf(a.rain, b.rain, s),
		lerpf(a.fog, b.fog, s), lerpf(a.snow, b.snow, s))

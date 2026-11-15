class_name Daylight
extends RefCounted
## The light over the valley, from the clock alone. There is no location
## lookup: day length follows the calendar for a mid-northern latitude, which
## is close enough for a toy and keeps Airship offline.
##
## Grove's light.rs is the spec.

## The sky's colour overhead and at the horizon.
var top := Color.BLACK
var bottom := Color.BLACK
## Height of the sun above the horizon from -1 to 1, negative at night.
var elevation := 0.0
## How far across the sky the sun or moon is, 0 at the left, 1 at the right.
var sun_x := 0.5
var moon_x := 0.5
## How high the moon is, 0 at the horizon and 1 overhead; -1 by day.
var moon_elevation := -1.0
## Whether the sun is above the horizon; when it isn't, the moon is up.
var sun_up := false
## 0 in darkness, 1 in full daylight; dims the garden, the hangar and the arm.
var ambient := 0.0
## How much the stars show, 0 by day to 1 in full dark.
var stars := 0.0
## Peaks near sunrise and sunset, when the light turns golden.
var warmth := 0.0
## The colour that golden light has, drawn toward the desktop accent.
var warm := Color.BLACK


## Sunrise and sunset as hours of the day, for a day of the year (1 for the
## first of January).
static func sun_times(day_of_year: int) -> Vector2:
	# Day length swings about 4.3 to 15.7 hours across the year, longest at
	# the June solstice (day 172); solar noon sits near 12:30 on the clock.
	var season := cos(TAU * (day_of_year - 172.0) / 365.0)
	var half := 6.07 + 1.78 * season
	return Vector2(12.5 - half, 12.5 + half)


## The sky at `hour` (0 up to 24) on `day_of_year`, its dusk warmed toward
## `accent`.
static func at(day_of_year: int, hour: float, accent: Color) -> Daylight:
	var sky := Daylight.new()
	var times := sun_times(day_of_year)
	var sunrise := times.x
	var sunset := times.y
	if hour >= sunrise and hour <= sunset:
		var u := (hour - sunrise) / (sunset - sunrise)
		sky.sun_up = true
		sky.elevation = sin(PI * u)
		sky.sun_x = u
		sky.moon_x = 0.5
		sky.moon_elevation = -1.0
	else:
		# The sun sinks only a little below the horizon, enough to take the
		# sky through twilight into darkness and back.
		var since_sunset := hour - sunset if hour >= sunset else hour + 24.0 - sunset
		var v := since_sunset / (24.0 - (sunset - sunrise))
		sky.sun_up = false
		sky.elevation = -0.4 * sin(PI * v)
		sky.sun_x = 0.5
		sky.moon_x = v
		sky.moon_elevation = sin(PI * v)
	# The horizon at golden hour is the warm colour, pulled toward the accent.
	sky.warm = Color.html("#e8905a").lerp(accent, 0.45)
	# Sky colours by the sun's height, from deep night to high noon.
	var stops: Array[Array] = [
		[-0.40, Color.html("#060a14"), Color.html("#0e1624")],
		[-0.15, Color.html("#0b1226"), Color.html("#1c1f3a")],
		[-0.02, Color.html("#1d2550"), Color.html("#6a4660")],
		[0.06, Color.html("#33497a"), sky.warm],
		[0.25, Color.html("#4a78a8"), Color.html("#9fc0cc")],
		[1.00, Color.html("#3d6f9c"), Color.html("#8fb4c8")],
	]
	var colours := _along(stops, sky.elevation)
	sky.top = colours[0]
	sky.bottom = colours[1]
	var d := (sky.elevation - 0.04) / 0.12
	sky.ambient = 0.22 + 0.78 * smoothstep(-0.12, 0.3, sky.elevation)
	sky.stars = clampf((-sky.elevation - 0.02) / 0.2, 0.0, 1.0)
	sky.warmth = exp(-d * d)
	return sky


## The colours between the stops on either side of `elevation`.
static func _along(stops: Array[Array], height: float) -> Array[Color]:
	if height <= float(stops[0][0]):
		return [stops[0][1], stops[0][2]]
	for k in range(1, stops.size()):
		var below: Array = stops[k - 1]
		var above: Array = stops[k]
		if height <= float(above[0]):
			var t := (height - float(below[0])) / (float(above[0]) - float(below[0]))
			return [(below[1] as Color).lerp(above[1] as Color, t), (below[2] as Color).lerp(above[2] as Color, t)]
	var last: Array = stops[stops.size() - 1]
	return [last[1], last[2]]


## The golden colour, with an alpha that rises with warmth, for tinting what
## the low sun lights.
func warm_tint() -> Color:
	return Color(warm, warmth * 0.2)


## A translucent blue that dims whatever it's laid over at night.
func night_tint() -> Color:
	return Color(0.02, 0.04, 0.12, (1.0 - ambient) * 0.62)


func equals(other: Daylight) -> bool:
	return top == other.top and bottom == other.bottom and elevation == other.elevation \
		and sun_x == other.sun_x and moon_x == other.moon_x and ambient == other.ambient

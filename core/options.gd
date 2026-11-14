class_name Options
extends RefCounted
## Airship's settings that come from the environment: the test knobs, and
## where the desktop keeps things. Nothing else reads the environment.
##
## AIRSHIP_SECONDS=30          a short session
## AIRSHIP_TIME=17:05          freeze the sky at that time
## AIRSHIP_DATE=2026-10-20     pin the date, and so the season
## AIRSHIP_WEATHER=fog         pin the weather: clear, cloudy, rain, snow or fog
##                             (any case: Fog works too)
## AIRSHIP_GARDEN=/path.json   use another garden file
## AIRSHIP_LANGUAGE=de         speak this language, whatever Omarchy says

const SESSION_SECONDS := 25 * 60
const WEATHERS: Array[String] = ["clear", "cloudy", "rain", "snow", "fog"]

## The session's length.
var seconds := SESSION_SECONDS
## Minutes after midnight the sky is frozen at, or -1 to follow the clock.
var time_minutes := -1
## The pinned date as {year, month, day}, or empty to follow the clock.
var date := {}
## The pinned weather, one of WEATHERS, or empty for the real forecast.
var weather := ""
## Another garden file, or empty for the usual one.
var garden_path := ""
## Where Airship keeps its data (the garden): XDG_DATA_HOME, else
## ~/.local/share. Empty if neither is set.
var data_directory := ""
## Omarchy's current theme (~/.local/state/omarchy/current), for the accent
## colour; empty if HOME isn't set.
var theme_directory := ""
## Omarchy's language file (~/.config/omarchy/language); empty if HOME isn't
## set.
var language_file := ""
## A pinned language code, or empty to follow Omarchy's.
var language := ""


static func from_environment() -> Options:
	return from_variables(func(name: String) -> String: return OS.get_environment(name))


## Options from named variables, as the environment gives them: `lookup`
## takes a name and returns its value, empty when unset. A value that doesn't
## parse is ignored, leaving the default.
static func from_variables(lookup: Callable) -> Options:
	var options := Options.new()
	var seconds_text := (lookup.call("AIRSHIP_SECONDS") as String).strip_edges()
	var seconds := _small_int(seconds_text, 9)
	if seconds > 0:
		options.seconds = seconds
	options.time_minutes = _parse_time(lookup.call("AIRSHIP_TIME") as String)
	options.date = _parse_date(lookup.call("AIRSHIP_DATE") as String)
	var weather_text := (lookup.call("AIRSHIP_WEATHER") as String).strip_edges().to_lower()
	if weather_text in WEATHERS:
		options.weather = weather_text
	options.garden_path = lookup.call("AIRSHIP_GARDEN") as String
	var data_home := lookup.call("XDG_DATA_HOME") as String
	var home := lookup.call("HOME") as String
	if not data_home.is_empty():
		options.data_directory = data_home
	elif not home.is_empty():
		options.data_directory = home.path_join(".local/share")
	if not home.is_empty():
		options.theme_directory = home.path_join(".local/state/omarchy/current")
		options.language_file = home.path_join(".config/omarchy/language")
	var language_text := (lookup.call("AIRSHIP_LANGUAGE") as String).strip_edges()
	# Only a real language code pins the language; anything else follows
	# Omarchy's.
	if Catalog.code_in(language_text) == language_text:
		options.language = language_text
	return options


## "HH:MM" as minutes after midnight, or -1.
static func _parse_time(text: String) -> int:
	var parts := text.strip_edges().split(":")
	if parts.size() != 2:
		return -1
	var hours := _small_int(parts[0], 2)
	var minutes := _small_int(parts[1], 2)
	if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
		return -1
	return hours * 60 + minutes


## "YYYY-MM-DD" as {year, month, day}, or empty if it isn't a real date.
static func _parse_date(text: String) -> Dictionary:
	var parts := text.strip_edges().split("-")
	if parts.size() != 3:
		return {}
	var year := _small_int(parts[0], 4)
	var month := _small_int(parts[1], 2)
	var day := _small_int(parts[2], 2)
	if year < 1 or month < 1 or month > 12 or day < 1 or day > days_in(year, month):
		return {}
	return {"year": year, "month": month, "day": day}


static func days_in(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## A whole number of at most `digits` digits, or -1. Checking the length
## first keeps a huge value from overflowing (or Godot from printing an error
## about it): 9 digits is under a billion, so seconds * 1000 still fits.
static func _small_int(text: String, digits: int) -> int:
	if text.is_empty() or text.length() > digits or not text.is_valid_int() or not text.lstrip("0123456789").is_empty():
		return -1
	return text.to_int()

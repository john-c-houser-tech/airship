extends TestCase
## The light, from Grove's light.rs tests.

# Days of 2026: 21 June, 6 November and 21 December.
const MIDSUMMER := 172
const NOVEMBER_6 := 310
const MIDWINTER := 355


func _sky(day: int, hour: float) -> Daylight:
	return Daylight.at(day, hour, App.DEFAULT_ACCENT)


func test_sunrise_is_earlier_in_summer() -> void:
	var summer := Daylight.sun_times(MIDSUMMER)
	var winter := Daylight.sun_times(MIDWINTER)
	check(summer.x < winter.x, "earlier sunrise")
	check(summer.y > winter.y, "later sunset")
	check(summer.y - summer.x > 15.0, "long summer day")
	check(winter.y - winter.x < 9.0, "short winter day")


func test_noon_is_bright_and_midnight_is_dark() -> void:
	var noon := _sky(MIDSUMMER, 12.5)
	var midnight := _sky(MIDSUMMER, 0.5)
	check(noon.sun_up and not midnight.sun_up, "sun up at noon only")
	same(noon.ambient, 1.0, "noon ambient")
	check(midnight.ambient < 0.3, "midnight is dark")
	same(noon.stars, 0.0, "no stars at noon")
	same(midnight.stars, 1.0, "stars at midnight")
	check(noon.top.get_luminance() > midnight.top.get_luminance(), "noon sky is lighter")


func test_light_turns_golden_at_sunset() -> void:
	var sunset := Daylight.sun_times(NOVEMBER_6).y
	check(_sky(NOVEMBER_6, sunset - 0.3).warmth > 0.5, "golden before sunset")
	check(_sky(NOVEMBER_6, 12.5).warmth < 0.05, "not at noon")
	check(_sky(NOVEMBER_6, 1.0).warmth < 0.05, "not at night")


func test_the_moon_shares_the_night_sky() -> void:
	var midnight := _sky(NOVEMBER_6, 0.0)
	check(midnight.moon_elevation > 0.5, "moon high")
	check(midnight.moon_x > 0.0 and midnight.moon_x < 1.0, "moon in the sky")


func test_the_accent_only_colours_dusk() -> void:
	same(Daylight.at(MIDSUMMER, 12.5, Color("#112233")).top, Daylight.at(MIDSUMMER, 12.5, App.DEFAULT_ACCENT).top, "noon")
	var sunset := Daylight.sun_times(NOVEMBER_6).y
	check(Daylight.at(NOVEMBER_6, sunset, Color("#112233")).bottom != Daylight.at(NOVEMBER_6, sunset, App.DEFAULT_ACCENT).bottom, "dusk")


func test_the_tints_follow_the_light() -> void:
	check(_sky(MIDSUMMER, 0.5).night_tint().a > 0.4, "night tint at midnight")
	same(_sky(MIDSUMMER, 12.5).night_tint().a, 0.0, "none at noon")
	check(_sky(MIDSUMMER, 12.5).warm_tint().a < 0.01, "no warm tint at noon")

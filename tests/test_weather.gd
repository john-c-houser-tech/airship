extends TestCase
## The weather and Airship's own random numbers, from Grove's weather.rs
## tests (less rain speeding growth, which Airship leaves out).

const NOVEMBER := 11


func _begun(forced: int, plant_seed: int, month: int) -> Weather:
	var weather := Weather.new(forced)
	weather.begin(plant_seed, month)
	return weather


## The share of 4000 rolls in `season` that come up `kind`.
func _share(kind: Weather.Kind, season: Weather.Season, seed_value: int) -> float:
	var random := Random.new(seed_value)
	var hits := 0
	for k in 4000:
		if Weather.pick(random, season) == kind:
			hits += 1
	return hits / 4000.0


func test_the_same_seed_gives_the_same_numbers() -> void:
	var a := Random.new(42)
	var b := Random.new(42)
	var c := Random.new(43)
	var first := a.next()
	same(first, b.next(), "same seed")
	check(first != c.next(), "neighbouring seeds differ")
	for k in 1000:
		var u := a.unit()
		check(u >= 0.0 and u < 1.0, "unit in range")


func test_the_numbers_are_xorshift32s_own() -> void:
	# Worked out separately (a few lines of Python), so a changed shift or
	# mask, which would change every garden's weather, can't slip through.
	var random := Random.new(42)
	same([random.next(), random.next(), random.next()], [3120216979, 1067267639, 2989017562], "seed 42")


func test_numbers_are_spread_evenly() -> void:
	var random := Random.new(7)
	var low := 0
	for k in 10000:
		if random.unit() < 0.5:
			low += 1
	check(low > 4800 and low < 5200, "about half below a half (%d)" % low)


func test_seasons_follow_the_calendar() -> void:
	same(Weather.season_of_month(4), Weather.Season.SPRING, "April")
	same(Weather.season_of_month(7), Weather.Season.SUMMER, "July")
	same(Weather.season_of_month(11), Weather.Season.AUTUMN, "November")
	same(Weather.season_of_month(1), Weather.Season.WINTER, "January")


func test_kinds_are_known_by_name() -> void:
	same(Weather.kind_named("fog"), Weather.Kind.FOG as int, "fog")
	same(Weather.kind_named("hail"), -1, "hail")
	same(Weather.kind_named(""), -1, "nothing")


func test_pinned_weather_never_changes() -> void:
	var weather := _begun(Weather.Kind.FOG, 5, NOVEMBER)
	for progress: float in [0.0, 0.5, 1.0]:
		weather.set_progress(progress)
		same(weather.kind(), Weather.Kind.FOG, "kind at %s" % progress)
	check(weather.now().fog > 0.8, "foggy")


func test_the_same_seed_gives_the_same_weather() -> void:
	var a := _begun(-1, 1234, NOVEMBER)
	var b := _begun(-1, 1234, NOVEMBER)
	for progress: float in [0.0, 0.5, 1.0]:
		a.set_progress(progress)
		b.set_progress(progress)
		same(a.kind(), b.kind(), "kind")
		check(a.now().equals(b.now()), "amounts")


func test_weather_can_change_during_a_session() -> void:
	var changed := 0
	for plant_seed in range(1, 100):
		var weather := _begun(-1, plant_seed, NOVEMBER)
		var start := weather.kind()
		weather.set_progress(1.0)
		if weather.kind() != start:
			changed += 1
	check(changed > 10, "some sessions change weather (%d of 99)" % changed)


func test_autumn_is_foggier_than_summer() -> void:
	check(_share(Weather.Kind.FOG, Weather.Season.AUTUMN, 99) > _share(Weather.Kind.FOG, Weather.Season.SUMMER, 99) * 2.0, "fog")


func test_snow_only_falls_in_winter() -> void:
	same(_share(Weather.Kind.SNOW, Weather.Season.SPRING, 5), 0.0, "spring")
	same(_share(Weather.Kind.SNOW, Weather.Season.SUMMER, 5), 0.0, "summer")
	same(_share(Weather.Kind.SNOW, Weather.Season.AUTUMN, 5), 0.0, "autumn")
	check(_share(Weather.Kind.SNOW, Weather.Season.WINTER, 5) > 0.15, "winter")


func test_snow_is_snow_not_rain() -> void:
	var weather := _begun(Weather.Kind.SNOW, 1, 1)
	same(weather.kind(), Weather.Kind.SNOW, "kind")
	check(weather.now().snow > 0.8, "snowy")
	same(weather.now().rain, 0.0, "no rain")


func test_steady_weather_is_never_redrawn() -> void:
	var weather := _begun(Weather.Kind.RAIN, 1, NOVEMBER)
	var redraws := 0
	for k in range(1, 101):
		if weather.set_progress(k / 100.0):
			redraws += 1
	same(redraws, 0, "redraws")


func test_changing_weather_is_announced_in_visible_steps_and_settles_exactly() -> void:
	for plant_seed in range(1, 100):
		var weather := _begun(-1, plant_seed, NOVEMBER)
		var jumped := _begun(-1, plant_seed, NOVEMBER)
		jumped.set_progress(1.0)
		if jumped.kind() == weather.kind():
			continue
		# A full session's worth of announced ticks.
		var redraws := 0
		for k in range(1, 1501):
			if weather.set_progress(k / 1500.0):
				redraws += 1
		check(redraws > 5 and redraws <= 110, "visible steps (%d)" % redraws)
		same(weather.kind(), jumped.kind(), "settles on the same kind")
		check(weather.now().equals(jumped.now()), "settles exactly")
		return
	check(false, "no seed changed the weather")


func test_a_generator_apart_does_not_follow_the_seeds_own() -> void:
	# The weather rolls from a seed's own generator; whatever else rolls
	# from that seed must not keep step with it.
	var together := 0
	for seed_value in 400:
		var own := Random.new(seed_value).unit() < 0.5
		var apart := Random.apart(seed_value, 0x5_0D5).unit() < 0.5
		if own == apart:
			together += 1
	check(together > 150 and together < 250, "about half agree by chance: %d of 400" % together)
	same(Random.apart(7, 3).next(), Random.apart(7, 3).next(), "the same every time")
	check(Random.apart(7, 3).next() != Random.apart(7, 4).next(), "another use, other numbers")

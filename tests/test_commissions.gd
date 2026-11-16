extends TestCase
## Commissions: what a visiting airship asks for, and what meets it.


func _plant(kind: int, weather: String, plant_seed: int, built := true, season := "spring") -> Garden.Plant:
	var plant := Garden.Plant.new()
	plant.blueprint = kind
	plant.plant_seed = plant_seed
	plant.outcome = Garden.Outcome.BUILT if built else Garden.Outcome.RUSTED
	plant.weather = weather
	plant.season = season
	return plant


## A valley's first five sessions, newest first: gourds in fog, which no
## commission asks for, the last with the seed that decides the first.
func _five(plant_seed: int, season := "spring") -> Array[Garden.Plant]:
	var plants: Array[Garden.Plant] = []
	for k in 4:
		plants.push_front(_plant(Parts.Kind.KETTLE_GOURD, "fog", 100 + k))
	plants.push_front(_plant(Parts.Kind.KETTLE_GOURD, "fog", plant_seed, true, season))
	return plants


func _weather_of(commission: Commissions.Commission) -> String:
	var wanted := Commissions.WEATHERS[commission.weather]
	return "fog" if wanted < 0 else Weather.KIND_NAMES[wanted]


func test_the_first_commission_comes_with_the_fifth_session() -> void:
	var plants := _five(7)
	var four: Array[Garden.Plant] = plants.slice(1)
	check(Commissions.state(four).open == null, "none after four sessions")
	four.push_front(_plant(0, "clear", 9, false))
	check(Commissions.state(four).open == null, "nor for a session given up")
	var now := Commissions.state(plants)
	check(now.open != null, "one after five")
	same(now.open.number, 0, "the valley's first")
	same(now.open.done, 0, "nothing built for it yet: what stood before doesn't count")
	same(now.met, 0, "no pennant yet")
	check(now.open.kind >= 0 and now.open.kind < Parts.Kind.KETTLE_GOURD, "it asks for one of the four quick plants")
	check(now.open.count >= 1 and now.open.count <= Commissions.ANY_WEATHER_COUNT, "of one to three plants")
	var again := Commissions.state(_five(7)).open
	same([again.kind, again.weather, again.count], [now.open.kind, now.open.weather, now.open.count], "the same every time")
	same(Commissions.WEATHER_PHRASES.size(), Commissions.WEATHERS.size(), "words for each weather")


func test_commissions_differ() -> void:
	var seen := {}
	for plant_seed in 40:
		var asked := Commissions.state(_five(plant_seed)).open
		seen["%d %d" % [asked.kind, asked.weather]] = true
	check(seen.size() >= 10, "forty seeds ask for at least ten different things: %d" % seen.size())


func test_only_the_plants_asked_for_count() -> void:
	for plant_seed in 12:
		var plants := _five(plant_seed)
		var asked := Commissions.state(plants).open
		var weather := _weather_of(asked)
		plants.push_front(_plant((asked.kind + 1) % 4, weather, 200))
		same(Commissions.state(plants).open.done, 0, "another kind of plant doesn't count")
		plants.push_front(_plant(asked.kind, weather, 201, false))
		same(Commissions.state(plants).open.done, 0, "nor one left to rust")
		if Commissions.WEATHERS[asked.weather] >= 0:
			plants.push_front(_plant(asked.kind, "snow", 202))
			same(Commissions.state(plants).open.done, 0, "nor one built in other weather")
		for k in asked.count:
			same(Commissions.state(plants).met, 0, "not met yet")
			same(Commissions.state(plants).open.done, k, "%d built so far" % k)
			plants.push_front(_plant(asked.kind, weather, 300 + k))
		var now := Commissions.state(plants)
		same(now.met, 1, "met: a pennant")
		same(now.open.number, 1, "and the next commission comes at once")
		same(now.open.done, 0, "with nothing built for it yet")


func test_any_weather_takes_any() -> void:
	for plant_seed in 60:
		var plants := _five(plant_seed)
		var asked := Commissions.state(plants).open
		if Commissions.WEATHERS[asked.weather] >= 0:
			continue
		plants.push_front(_plant(asked.kind, "snow", 400))
		plants.push_front(_plant(asked.kind, "rain", 401))
		same(Commissions.state(plants).open.done, 2, "snow and rain both count")
		return
	check(false, "no seed in sixty asked for any weather")


func test_a_weather_is_asked_for_only_where_it_is_common_enough() -> void:
	var asked_weathers := {}
	for season: String in Weather.SEASON_NAMES:
		var at := Weather.SEASON_NAMES.find(season)
		for plant_seed in 200:
			var asked := Commissions.state(_five(plant_seed, season)).open
			var wanted := Commissions.WEATHERS[asked.weather]
			if wanted < 0:
				same(asked.count, Commissions.ANY_WEATHER_COUNT, "three in any weather")
				continue
			asked_weathers["%s %d" % [season, wanted]] = true
			check(Commissions._common(wanted, at),
				"%s in %s comes often enough, this season and next" % [Weather.KIND_NAMES[wanted], season])
			same(asked.count, 2 if Commissions._share(wanted, at) >= Commissions.USUAL_SHARE else 1,
				"two only where the weather is the usual one")
	check(not asked_weathers.has("summer %d" % Weather.Kind.RAIN), "no rain asked for in summer")
	check(not asked_weathers.has("winter %d" % Weather.Kind.CLEAR), "no clear sky asked for in winter")
	check(not asked_weathers.has("spring %d" % Weather.Kind.RAIN), "nor in spring, with summer coming")
	check(asked_weathers.has("autumn %d" % Weather.Kind.RAIN), "rain is asked for in autumn")
	check(asked_weathers.has("spring %d" % Weather.Kind.CLEAR), "a clear sky in spring")
	check(asked_weathers.has("summer %d" % Weather.Kind.CLEAR), "and in summer, two plants of it")
	check(asked_weathers.has("winter %d" % Weather.Kind.CLOUDY), "and cloud in winter")
	var none := Commissions.state(_five(3, "")).open
	check(Commissions.WEATHERS[none.weather] < 0 or Commissions.WEATHERS[none.weather] == Weather.Kind.CLOUDY,
		"a plant of no known season asks for cloud at most")


func test_the_kind_asked_does_not_follow_the_bringing_plants_weather() -> void:
	# The weather rolls from the same seed: the commission must not track it.
	var kinds_by_weather := {}
	for plant_seed in 400:
		var weather := Weather.pick(Random.new(plant_seed), Weather.Season.SPRING)
		var asked := Commissions.state(_five(plant_seed)).open
		if not kinds_by_weather.has(weather):
			kinds_by_weather[weather] = {}
		(kinds_by_weather[weather] as Dictionary)[asked.kind] = true
	for weather: int in kinds_by_weather:
		same((kinds_by_weather[weather] as Dictionary).size(), 4, "every kind is asked after %s" % Weather.KIND_NAMES[weather])


func test_the_next_commission_comes_from_the_plant_that_met_the_last() -> void:
	var plants := _five(5)
	var first := Commissions.state(plants).open
	for k in first.count:
		plants.push_front(_plant(first.kind, _weather_of(first), 500 + k))
	var second := Commissions.state(plants).open
	var other := _five(5)
	for k in first.count:
		other.push_front(_plant(first.kind, _weather_of(first), 900 + k))
	var differs := false
	for k in 20:
		# Another meeting plant's seed, another commission (for some seed).
		other[0].plant_seed = 900 + k
		var asked := Commissions.state(other).open
		differs = differs or asked.kind != second.kind or asked.weather != second.weather
	check(differs, "what the second asks follows from the plant that met the first")
	# Rusted plants between don't move anything.
	plants.insert(first.count, _plant(first.kind, _weather_of(first), 77, false))
	var same_again := Commissions.state(plants)
	same([same_again.met, same_again.open.kind, same_again.open.weather], [1, second.kind, second.weather], "a session given up in between changes nothing")


func test_the_visitor_is_here_while_its_commission_is_the_newest_news() -> void:
	var plants := _five(5)
	check(Commissions.state(plants).fresh, "the fifth session's plant brought it")
	var asked := Commissions.state(plants).open
	plants.push_front(_plant((asked.kind + 1) % 4, "fog", 600))
	check(not Commissions.state(plants).fresh, "after another session it has gone")
	plants.pop_front()
	plants.push_front(_plant(asked.kind, "fog", 601, false))
	check(not Commissions.state(plants).fresh, "also after one given up")
	plants.pop_front()
	for k in asked.count:
		same(Commissions.state(plants).fresh, k == 0, "here when it asks, not while the commission is under way")
		plants.push_front(_plant(asked.kind, _weather_of(asked), 610 + k))
	check(Commissions.state(plants).fresh, "the plant that meets one brings the next, and its airship")
	check(not Commissions.state(plants.slice(1, 5)).fresh, "no commission, no visitor")

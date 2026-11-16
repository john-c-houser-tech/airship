extends TestCase
## The economy: what plants make and what the airship needs.


## A garden, newest first, from blueprints listed oldest first; a negative
## number is that blueprint (as -n - 1) left to rust.
func _garden(oldest_first: Array[int]) -> Array[Garden.Plant]:
	var plants: Array[Garden.Plant] = []
	for blueprint: int in oldest_first:
		var plant := Garden.Plant.new()
		plant.blueprint = blueprint if blueprint >= 0 else -blueprint - 1
		plant.outcome = Garden.Outcome.BUILT if blueprint >= 0 else Garden.Outcome.RUSTED
		plants.push_front(plant)
	return plants


func test_every_blueprint_is_some_plant() -> void:
	same(Parts.kind_of(0), Parts.Kind.GEAR_FLOWER, "an old garden's plants are gear-flowers")
	same(Parts.kind_of(4), Parts.Kind.KETTLE_GOURD, "the last kind")
	same(Parts.kind_of(7), Parts.Kind.GIRDER_REED, "past the list, round again")
	same(Parts.kind_of(-1), Parts.Kind.KETTLE_GOURD, "even a negative number")
	same(Parts.PLANT_NAMES.size(), Parts.KINDS, "a name for each plant")
	same(Parts.PART_NAMES.size(), Parts.KINDS, "a name for each part")
	same(Parts.NEEDED.size(), Parts.KINDS, "a need for each part")
	same(Parts.SESSIONS_A_PART.size(), Parts.KINDS, "a pace for each part")


func test_a_plant_makes_a_part_each_later_session() -> void:
	same(Parts.made(_garden([])), [0, 0, 0, 0, 0] as Array[int], "an empty garden")
	same(Parts.made(_garden([0])), [0, 0, 0, 0, 0] as Array[int], "a new plant has made nothing")
	same(Parts.made(_garden([0, 1])), [1, 0, 0, 0, 0] as Array[int], "one session later, one cog")
	same(Parts.made(_garden([0, 1, 2, 2])), [3, 2, 1, 0, 0] as Array[int], "older plants have made more")


func test_rust_makes_nothing_and_ripens_nothing() -> void:
	same(Parts.made(_garden([0, -1, -1])), [0, 0, 0, 0, 0] as Array[int], "sessions given up ripen nothing")
	same(Parts.made(_garden([-1, 0, 0])), [1, 0, 0, 0, 0] as Array[int], "a rusted plant makes nothing")
	same(Parts.standing(_garden([0, -1, 3, 3])), [1, 0, 0, 2, 0] as Array[int], "only built plants stand")


func test_a_kettle_gourd_ripens_every_fifth_session() -> void:
	same(Parts.made(_garden([4, 0, 0, 0, 0]))[Parts.Kind.KETTLE_GOURD], 0, "four sessions: not yet")
	same(Parts.made(_garden([4, 0, 0, 0, 0, 0]))[Parts.Kind.KETTLE_GOURD], 1, "five sessions: a drum")
	same(Parts.made(_garden([4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))[Parts.Kind.KETTLE_GOURD], 2, "ten: two")


func test_the_airship_needs_every_kind() -> void:
	same(Parts.airship_built([0, 0, 0, 0, 0] as Array[int]), 0.0, "no parts, no ship")
	same(Parts.airship_built(Parts.NEEDED), 1.0, "every part makes a whole ship")
	same(Parts.airship_built([999, 999, 999, 999, 999] as Array[int]), 1.0, "never past a whole ship")
	same(Parts.airship_built([999, 0, 0, 0, 0] as Array[int]), 12.0 / 70.0, "cogs alone don't fly")


func test_the_next_plant_is_the_one_most_needed() -> void:
	same(Parts.most_needed(_garden([])), Parts.Kind.GIRDER_REED, "struts first: the ship needs most of them")
	same(Parts.most_needed(_garden([2])), Parts.Kind.SAIL_COTTON, "then cloth")
	same(Parts.most_needed(_garden([2, 3])), Parts.Kind.GEAR_FLOWER, "then cogs and tubing, the lower first")
	same(Parts.most_needed(_garden([2, 3, 0])), Parts.Kind.PIPE_VINE, "tubing")
	var plants := _garden([])
	for k in 60:
		var plant := Garden.Plant.new()
		plant.blueprint = Parts.most_needed(plants)
		plants.push_front(plant)
	check(Parts.standing(plants)[Parts.Kind.KETTLE_GOURD] > 0, "a kettle-gourd gets planted in time")
	same(Parts.airship_built(Parts.made(plants)), 1.0, "sixty sessions of the suggested plants build the ship")
	same(Parts.most_needed(plants), Parts.Kind.GEAR_FLOWER, "a whole ship wants nothing: a gear-flower")
	same(Parts.most_needed(_garden([-3, -3, -3])), Parts.Kind.GIRDER_REED, "rusted reeds don't count as standing")


func test_about_fourteen_sessions_build_an_airship() -> void:
	var plants := _garden([])
	var sessions := 0
	while Parts.airship_built(Parts.made(plants)) < 1.0 and sessions < 200:
		var plant := Garden.Plant.new()
		plant.blueprint = Parts.most_needed(plants)
		plants.push_front(plant)
		sessions += 1
	check(sessions >= 12 and sessions <= 16, "the suggested plants build a ship in %d sessions" % sessions)


func test_blueprints_unlock_as_the_airship_grows() -> void:
	same(Parts.unlocked(0.0), [Parts.Kind.GIRDER_REED, Parts.Kind.SAIL_COTTON] as Array[int], "frame and cloth to start")
	same(Parts.unlocked(1.0 / 70.0), [0, 1, 2, 3] as Array[int], "the first part on the ship brings cogs and tubing")
	same(Parts.unlocked(0.1), [0, 1, 2, 3, 4] as Array[int], "a tenth built brings the kettle-gourd")
	same(Parts.unlocked(1.0), [0, 1, 2, 3, 4] as Array[int], "all five on a whole ship")
	same(Parts.most_needed(_garden([2, 3])), Parts.Kind.GEAR_FLOWER, "the suggestion keeps to what is unlocked")


func test_parts_wait_until_they_are_fitted() -> void:
	same(Parts.waiting([3, 0, 5, 0, 0] as Array[int], [] as Array[int]), [3, 0, 5, 0, 0] as Array[int], "nothing fitted yet")
	same(Parts.waiting([3, 0, 5, 0, 0] as Array[int], [1, 0, 5] as Array[int]), [2, 0, 0, 0, 0] as Array[int], "less what is on the ship")
	same(Parts.waiting([99, 0, 0, 0, 9] as Array[int], [0, 0, 0, 0, 0] as Array[int]), [12, 0, 0, 0, 2] as Array[int], "no more than the ship needs")
	same(Parts.waiting([1, 0, 0, 0, 0] as Array[int], [5, 0, 0, 0, 0] as Array[int]), [0, 0, 0, 0, 0] as Array[int], "never less than none")
	same(Parts.airship_built([0, 0, 7] as Array[int]), 7.0 / 70.0, "a short list of fitted parts counts too")


func test_each_completed_session_earns_one_scrape_of_the_oldest_rust() -> void:
	same(Parts.to_scrape(_garden([-3])), -1, "no session completed since it rusted")
	same(Parts.to_scrape(_garden([2, -3])), -1, "a session before the rust doesn't count")
	same(Parts.to_scrape(_garden([-3, 2])), 1, "a session completed since: scrape it")
	same(Parts.to_scrape(_garden([-3, -4, 2])), 2, "the oldest first")
	var plants := _garden([-3, -4, 2])
	plants[2].scraped = 1
	same(Parts.to_scrape(plants), -1, "one session, one scrape: the other waits")
	plants = _garden([-3, -4, 2, 2])
	plants[3].scraped = 1
	same(Parts.to_scrape(plants), 2, "the next session earns the next")
	same(Parts.to_scrape(_garden([2, 2])), -1, "nothing rusted")
	plants = _garden([2, -3, -4, 2])
	same(Parts.to_scrape(plants), 2, "one session since the rust: the older of the two")
	plants[2].scraped = 2
	same(Parts.to_scrape(plants), -1, "and only one: the session from before the rust earns nothing")
	plants = _garden([2, 2, 2, -3, 2])
	same(Parts.to_scrape(plants), 1, "three old sessions and one since: one scrape")
	plants[1].scraped = 4
	plants = _garden([2, 2, 2, -3, 2, -4])
	plants[2].scraped = 4
	same(Parts.to_scrape(plants), -1, "a second rust waits for its own later session")
	plants = _garden([-3, -4, 2, 2])
	same(Parts.to_scrape(plants), 3, "two sessions since, breaks skipped")
	plants[3].scraped = 2
	same(Parts.to_scrape(plants), 2, "the skipped scrape waited: both in one break")
	var gourd := _garden([-5, 2, 2, 2, 2, 2, 2])
	gourd[6].scraped = 1
	same(Parts.made(gourd)[Parts.Kind.KETTLE_GOURD], 1, "a scraped kettle-gourd ripens every fifth session since")
	gourd[6].scraped = 9
	same(Parts.made(gourd)[Parts.Kind.KETTLE_GOURD], 0, "a mark past the sessions there are makes nothing")


func test_a_scraped_plant_works_from_then_on() -> void:
	var plants := _garden([-4, 2, 2, 2])
	same(Parts.made(plants), [0, 0, 3, 0, 0] as Array[int], "rusted: only the reeds make parts")
	same(Parts.standing(plants), [0, 0, 3, 0, 0] as Array[int], "and only they stand")
	# Scraped after the first of the three sessions.
	plants[3].scraped = 1
	check(Parts.stands(plants[3]), "it stands again")
	same(Parts.standing(plants), [0, 0, 3, 1, 0] as Array[int], "counted with the rest")
	same(Parts.made(plants), [0, 0, 3, 2, 0] as Array[int], "a part for each session since, none for those before")
	plants[3].scraped = 3
	same(Parts.made(plants)[Parts.Kind.SAIL_COTTON], 0, "just scraped: nothing yet")
	same(Parts.sessions(plants), 3, "a scraped plant is no session")


func _flowers(n: int) -> Array[Garden.Plant]:
	var blueprints: Array[int] = []
	blueprints.resize(n)
	blueprints.fill(Parts.Kind.GEAR_FLOWER)
	return _garden(blueprints)


func test_parts_to_hand_count_the_trades() -> void:
	same(Parts.have([15, 0, 2, 0, 0] as Array[int], [3] as Array[int], [0, 0, 1] as Array[int]),
		[12, 0, 3, 0, 0] as Array[int], "less the spares given, and the part brought")
	same(Parts.have([1, 0, 0, 0, 0] as Array[int], [3] as Array[int], [] as Array[int]),
		[0, 0, 0, 0, 0] as Array[int], "never below nothing, should the garden have changed")


func test_the_night_train_brings_what_the_garden_is_slowest_to_make() -> void:
	var none: Array[int] = []
	# Five gear-flowers have made ten cogs, and nothing makes a strut.
	var offer := Parts.trade(_flowers(5), none, none)
	check(offer != null, "five sessions: a trade")
	same(offer.gives, Parts.Kind.GEAR_FLOWER, "it takes cogs, which the garden makes fast")
	same(offer.brings, Parts.Kind.GIRDER_REED, "and brings a strut: 24 to make and no plant for them")
	check(Parts.trade(_flowers(7), [3] as Array[int], [0, 0, 1] as Array[int]) == null, "one trade for five sessions")
	check(Parts.trade(_flowers(10), [3] as Array[int], [0, 0, 1] as Array[int]) != null, "ten sessions earn a second")
	check(Parts.trade(_flowers(10), none, none) != null, "a trade not taken waits")


func test_the_night_train_takes_what_the_garden_can_best_spare() -> void:
	var none: Array[int] = []
	# One flower and vine, three reeds and cottons, two gourds: 5 cogs,
	# 4 tubing, 19 struts, 16 cloth, no drum yet.
	var mixed := _garden([2, 3, 2, 3, 0, 1, 2, 3, 4, 4] as Array[int])
	same(Parts.made(mixed), [5, 4, 19, 16, 0] as Array[int], "the garden")
	var offer := Parts.trade(mixed, none, none)
	same(offer.brings, Parts.Kind.PIPE_VINE, "tubing: eight to go from one vine is the longest wait, longer than the gourds' drums")
	same(offer.gives, Parts.Kind.SAIL_COTTON, "cloth is nearest done; struts and cloth are as fast, and it isn't the lower number that decides")
	# Six flowers and six reeds: 51 cogs, far more than the ship needs.
	var spares := _garden([0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2] as Array[int])
	same(Parts.trade(spares, none, none).gives, Parts.Kind.GEAR_FLOWER, "spares go first, though the reeds are as fast")
	same(Parts.trade(mixed, none, none, [0, 8, 0, 0, 0] as Array[int]).brings, Parts.Kind.PIPE_VINE, "a kind the ship still has room for")
	check(Parts.trade(mixed, none, none, [0, 12, 0, 0, 0] as Array[int]).brings != Parts.Kind.PIPE_VINE, "never one the ship is full of")


func test_no_trade_without_sessions_parts_or_gain() -> void:
	var none: Array[int] = []
	check(Parts.trade(_flowers(4), none, none) == null, "four sessions earn none")
	check(Parts.trade(_flowers(5), [8] as Array[int], none) == null, "fewer than three cogs left to give")
	# Four of each common plant, and both drums brought: nothing is missing.
	var even: Array[int] = []
	for k in 16:
		even.append(k % 4)
	check(Parts.trade(_garden(even), [6] as Array[int], [0, 0, 0, 0, 2] as Array[int]) == null, "a ship with every part needs no trade")
	# Three reeds and three flowers, the rest of the ship fitted: 12 struts
	# to go and 9 cogs. Three cogs for a strut would leave the cogs the
	# last to be done, no sooner than the struts are now.
	var rest: Array[int] = [0, 12, 0, 20, 2]
	check(Parts.trade(_garden([2, 2, 2, 0, 0, 0] as Array[int]), none, none, rest) == null, "a trade that wouldn't help isn't offered")
	# A garden of rusted plants made nothing and completed nothing.
	check(Parts.trade(_garden([-1, -1, -1, -1, -1, -1] as Array[int]), none, none) == null, "nothing made, nothing to trade")


func test_the_plant_most_needed_counts_what_the_train_brought() -> void:
	var garden := _garden([2, 3, 0, 1, 2, 3] as Array[int])
	var open: Array[int] = [0, 1, 2, 3, 4]
	same(Parts.most_needed(garden, open), Parts.Kind.KETTLE_GOURD, "no drums and no gourd: a gourd")
	check(Parts.most_needed(garden, open, [] as Array[int], [0, 0, 0, 0, 2] as Array[int]) != Parts.Kind.KETTLE_GOURD, "both drums brought: no gourd needed")

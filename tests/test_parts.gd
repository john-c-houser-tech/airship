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

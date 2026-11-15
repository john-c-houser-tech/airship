class_name Parts
extends RefCounted
## What the garden makes and what the airship needs: the game's economy, as
## plain sums over the garden's plants. How many parts have been made
## follows from which plants stand and in what order the garden saved them;
## the garden file keeps only how many were fitted to the airship, in the
## break after a session.
##
## Each plant is of one kind, by its blueprint, and makes one kind of part
## for as long as it stands. Only focus moves the game forward: a plant
## makes its part each time a later session is completed (a kettle-gourd,
## slow to ripen, every fifth), never by the clock. A rusted plant makes
## nothing until a later session's break scrapes it clean, and a session
## given up ripens nothing.

## The five plants, by blueprint, and the part each makes.
enum Kind { GEAR_FLOWER, PIPE_VINE, GIRDER_REED, SAIL_COTTON, KETTLE_GOURD }

const KINDS := 5
## In English; the window translates what it shows.
const PLANT_NAMES: Array[String] = ["gear-flower", "pipe-vine", "girder-reed", "sail-cotton", "kettle-gourd"]
const PART_NAMES: Array[String] = ["cogs", "copper tubing", "struts", "cloth", "boiler drums"]
## Completed sessions a plant of each kind takes to make one part.
const SESSIONS_A_PART: Array[int] = [1, 1, 1, 1, 5]
## The parts one airship takes: cogs for the engines, tubing for the steam
## lines, struts for the frame, cloth for the envelope, boiler drums.
## About fourteen well-chosen sessions build it.
const NEEDED: Array[int] = [12, 12, 24, 20, 2]


## The kind of plant a blueprint builds. Every number is some plant, so a
## garden from before there were kinds (all blueprint 0) reads as gear-flowers.
static func kind_of(blueprint: int) -> Kind:
	return posmod(blueprint, KINDS) as Kind


## Whether a plant stands and works: built to the end, or left to rust and
## scraped clean since.
static func stands(plant: Garden.Plant) -> bool:
	return plant.outcome == Garden.Outcome.BUILT or plant.scraped >= 0


## How many plants of each kind stand and work, by kind.
static func standing(plants: Array[Garden.Plant]) -> Array[int]:
	var counts := _none()
	for plant: Garden.Plant in plants:
		if stands(plant):
			counts[kind_of(plant.blueprint)] += 1
	return counts


## How many sessions were completed: the plants built to the end.
static func sessions(plants: Array[Garden.Plant]) -> int:
	var built := 0
	for plant: Garden.Plant in plants:
		if plant.outcome == Garden.Outcome.BUILT:
			built += 1
	return built


## The parts the garden has made so far, by kind. `plants` is newest first,
## as the garden keeps them: each built plant has made a part for every
## so-many sessions completed since it was built, and a scraped one for
## those completed since its rust came off.
static func made(plants: Array[Garden.Plant]) -> Array[int]:
	var parts := _none()
	var completed := sessions(plants)
	var later := 0
	for plant: Garden.Plant in plants:
		var kind := kind_of(plant.blueprint)
		if plant.outcome == Garden.Outcome.BUILT:
			parts[kind] += later / SESSIONS_A_PART[kind]
			later += 1
		elif plant.scraped >= 0:
			parts[kind] += maxi(completed - plant.scraped, 0) / SESSIONS_A_PART[kind]
	return parts


## The rusted plant to scrape clean next, as its place in `plants`, or -1.
## Each session completed after a plant rusted earns one scrape, of the
## oldest plant still seized; sessions from before the rust earn none, and
## a scrape not taken waits (a skipped break loses nothing).
static func to_scrape(plants: Array[Garden.Plant]) -> int:
	var completed := sessions(plants)
	# Built plants older than the one looked at, counted from the oldest.
	var older := 0
	for k in range(plants.size() - 1, -1, -1):
		var plant := plants[k]
		if plant.outcome == Garden.Outcome.BUILT:
			older += 1
			continue
		if plant.scraped >= 0:
			continue
		# The sessions since it rusted, less the scrapes they already paid
		# for (a scrape's mark is the sessions completed by then).
		var spent := 0
		for other: Garden.Plant in plants:
			if other.scraped > older:
				spent += 1
		return k if completed - older - spent > 0 else -1
	return -1


## The parts ready for the airship: those made, as many as the ship needs,
## that aren't `fitted` yet. By kind.
static func waiting(made_: Array[int], fitted: Array[int]) -> Array[int]:
	var ready := _none()
	for kind in KINDS:
		var on_ship := fitted[kind] if kind < fitted.size() else 0
		ready[kind] = maxi(mini(made_[kind], NEEDED[kind]) - on_ship, 0)
	return ready


## How far the airship is built from the parts fitted, 0 to 1. Parts past what
## the ship needs of a kind add nothing: forty gear-flowers alone don't fly.
static func airship_built(parts: Array[int]) -> float:
	var fitted := 0
	var whole := 0
	for kind in KINDS:
		fitted += mini(parts[kind] if kind < parts.size() else 0, NEEDED[kind])
		whole += NEEDED[kind]
	return float(fitted) / whole


## The blueprints to hand, which unlock as the airship grows: the frame's
## girder-reed and the envelope's sail-cotton from the start, the
## gear-flower and the pipe-vine once the first part is on the ship, and
## the kettle-gourd when a tenth of it is built.
static func unlocked(airship: float) -> Array[int]:
	var kinds: Array[int] = [Kind.GIRDER_REED, Kind.SAIL_COTTON]
	if airship > 0.0:
		kinds.append_array([Kind.GEAR_FLOWER, Kind.PIPE_VINE])
	if airship >= 0.1:
		kinds.append(Kind.KETTLE_GOURD)
	kinds.sort()
	return kinds


## The plant the airship most needs next, of those unlocked (`open`): the kind whose
## missing parts would take the longest for the plants already standing,
## and one more, to make. A rough guide for when nobody chooses (it plants
## more kettle-gourds than the drums need). Once the ship has every part,
## the first of those unlocked.
static func most_needed(plants: Array[Garden.Plant], open: Array[int] = []) -> Kind:
	var parts := made(plants)
	var counts := standing(plants)
	if open.is_empty():
		# Nobody said which are unlocked: as if every part made were fitted.
		open = unlocked(airship_built(parts))
	var best := open[0] as Kind
	var longest := -1.0
	for kind: int in open:
		var missing := maxi(NEEDED[kind] - parts[kind], 0)
		var sessions := float(missing * SESSIONS_A_PART[kind]) / (counts[kind] + 1)
		if sessions > longest:
			longest = sessions
			best = kind as Kind
	return best


static func _none() -> Array[int]:
	var zeros: Array[int] = []
	zeros.resize(KINDS)
	zeros.fill(0)
	return zeros

class_name Parts
extends RefCounted
## What the garden makes and what the airship needs: the game's economy, as
## plain sums over the garden's plants. Nothing here is saved: how many parts
## there are follows from which plants stand and in what order the garden
## saved them, so the garden file stays the one record.
##
## Each plant is of one kind, by its blueprint, and makes one kind of part
## for as long as it stands. Only focus moves the game forward: a plant
## makes its part each time a later session is completed (a kettle-gourd,
## slow to ripen, every fifth), never by the clock. A rusted plant makes
## nothing, and a session given up ripens nothing.

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


## How many plants of each kind stand built, by kind.
static func standing(plants: Array[Garden.Plant]) -> Array[int]:
	var counts := _none()
	for plant: Garden.Plant in plants:
		if plant.outcome == Garden.Outcome.BUILT:
			counts[kind_of(plant.blueprint)] += 1
	return counts


## The parts the garden has made so far, by kind. `plants` is newest first,
## as the garden keeps them: each built plant has made a part for every
## so-many sessions completed since it was built.
static func made(plants: Array[Garden.Plant]) -> Array[int]:
	var parts := _none()
	var later := 0
	for plant: Garden.Plant in plants:
		if plant.outcome != Garden.Outcome.BUILT:
			continue
		var kind := kind_of(plant.blueprint)
		parts[kind] += later / SESSIONS_A_PART[kind]
		later += 1
	return parts


## How far the airship is built from the parts made, 0 to 1. Parts past what
## the ship needs of a kind add nothing: forty gear-flowers alone don't fly.
static func airship_built(parts: Array[int]) -> float:
	var fitted := 0
	var whole := 0
	for kind in KINDS:
		fitted += mini(parts[kind], NEEDED[kind])
		whole += NEEDED[kind]
	return float(fitted) / whole


## The plant the airship most needs next: the kind whose missing parts would
## take the longest for the plants already standing, and one more, to make.
## A rough guide for when nobody chooses (it plants more kettle-gourds than
## the drums need). Once the ship has every part, a gear-flower.
static func most_needed(plants: Array[Garden.Plant]) -> Kind:
	var parts := made(plants)
	var counts := standing(plants)
	var best := Kind.GEAR_FLOWER
	var longest := -1.0
	for kind in KINDS:
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

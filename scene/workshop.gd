extends "res://scene/corner_canvas.gd"
## The live part of the scene: the arm building the plant, the boiler's fire
## and gauge, the parts bin's front, the planter's front and the steam,
## stood on the hangar's floor (corner_canvas.gd). Redrawn every frame while
## the arm works.
##
## What it shows comes from the session alone (its blueprint, `state` and
## `progress`); the window redraws it only while the arm works.

const BuildPlan := preload("res://scene/build_plan.gd")
const Machinery := preload("res://scene/machinery.gd")

const BASE := Vector2(262, 640)
const UPPER := 235.0
const FORE := 225.0
## From the wrist to the point between the jaws, where a held part is.
const GRIP := 30.0
const PLANT_X := 450.0
const GROUND := 640.0
const HEAD := Vector2(450, 318)
const VALVE := Vector2(72, 414)
const BRASS := Color(0.82, 0.60, 0.27)
const BRASS_DARK := Color(0.50, 0.33, 0.14)
const COPPER := Color(0.74, 0.42, 0.25)
const IRON := Color(0.24, 0.22, 0.21)
const RUST := Color(0.55, 0.30, 0.18)

const ALLOY := Color(0.70, 0.74, 0.78)
const CANVAS := Color(0.90, 0.85, 0.72)

## The shapes a plant's parts come in.
enum { BAR, DISC, LEAF, PETAL, HUB }


## One part of a plant: what the arm picks up, and where it sets it.
class Piece:
	var shape := BAR
	## Where the arm holds it and sets it down.
	var spot: Vector2
	## A bar runs from its spot by this much; a leaf's root is this far off.
	var reach: Vector2
	## A bar's width, a disc's radius.
	var size := 0.0
	var colour: Color
	## A bar's bright line along its length.
	var shine := true
	## A bar held by its middle (a wide one, so it fits the parts bin),
	## where others are held by an end.
	var centred := false

var state := Session.State.IDLE
## How far through the session, 0 to 1.
var progress := 0.0
## Real seconds per second of the build plan: 1 for a full session, less for
## one shortened by AIRSHIP_SECONDS.
var time_scale := 1.0
var plan: BuildPlan
## Whether the plant just built has gone out to the garden: until then it
## stands finished on the planter.
var planted := true
## The plant being built (Parts.Kind).
var kind := Parts.Kind.GEAR_FLOWER

var _pieces: Array[Piece] = []
# Seconds into the build plan, which always runs a 25-minute session (a
# shortened one plays it faster).
var _t := 0.0
var _boiler_steam: GPUParticles2D
# One vent on each piston, puffing while it draws in.
var _upper_steam: GPUParticles2D
var _fore_steam: GPUParticles2D


## Where the arm's bones and pistons are for one reach of the gripper.
class Limbs:
	var shoulder: Vector2
	var elbow: Vector2
	var wrist: Vector2
	## Along the forearm.
	var dir: Vector2
	## Each piston: its cylinder's foot and its rod's end.
	var upper_foot: Vector2
	var upper_end: Vector2
	var fore_foot: Vector2
	var fore_end: Vector2


func _ready() -> void:
	_lay_out()
	_boiler_steam = _steam(VALVE, 26, 3.2, 0.9)
	# Placed on their pistons each time the session is shown. They start
	# from nothing, where the boiler's plume stands ready: a piston's puff
	# begins small each time it draws in.
	_upper_steam = _steam(BASE, 14, 1.1, 1.5)
	_fore_steam = _steam(BASE, 12, 1.0, 1.5)
	_upper_steam.preprocess = 0.0
	_fore_steam.preprocess = 0.0
	show_session(state, progress)


## Puts the corner on the hangar's floor, and the boiler's steam vent
## where its valve lands, sized for the distance.
func stand_in(hangar_: Hangar) -> void:
	super.stand_in(hangar_)
	_place(_boiler_steam, VALVE)
	show_session(state, progress)


func _place(vent: GPUParticles2D, spot: Vector2) -> void:
	vent.position = at(spot)
	vent.scale = Vector2.ONE * px(spot)


## Builds the plant of `blueprint` from here on.
func show_blueprint(blueprint: int) -> void:
	var next := Parts.kind_of(blueprint)
	if next != kind:
		kind = next
		_lay_out()
		queue_redraw()


## Shows the session as it stands, and lets the steam run while the arm
## works (it dies away when the arm rests or the session ends).
func show_session(state_: Session.State, progress_: float) -> void:
	state = state_
	progress = progress_
	_t = progress * BuildPlan.SESSION
	if _boiler_steam == null:
		return
	var pose := _pose()
	var working := state == Session.State.BUILDING
	_boiler_steam.emitting = working and not pose.resting
	# A piston vents its spent steam as it draws in: found by looking a
	# moment back in the plan, so nothing is remembered between frames.
	var now := _limbs(pose.tip)
	var before := _limbs(_pose_at(_t - 0.4).tip)
	var moving := working and not pose.resting
	_upper_steam.emitting = moving and now.upper_foot.distance_to(now.upper_end) < before.upper_foot.distance_to(before.upper_end) - 0.25
	_fore_steam.emitting = moving and now.fore_foot.distance_to(now.fore_end) < before.fore_foot.distance_to(before.fore_end) - 0.25
	if hangar != null:
		_place(_upper_steam, now.upper_foot.lerp(now.upper_end, 0.55))
		_place(_fore_steam, now.fore_foot.lerp(now.fore_end, 0.55))
	queue_redraw()


## Real seconds the arm has rested, so the window knows when the steam has
## died away; 0 while it moves.
func resting_for() -> float:
	if state != Session.State.BUILDING:
		return INF
	return plan.rest_so_far(_t) * time_scale


func _pose() -> BuildPlan.Pose:
	return _pose_at(_t)


func _pose_at(t: float) -> BuildPlan.Pose:
	if state == Session.State.BUILDING or state == Session.State.RUSTED:
		var pose := plan.pose(t)
		if state == Session.State.RUSTED:
			# Seized where it stood: no part in hand, the arm back at rest.
			pose.carrying = -1
			pose.tip = BuildPlan.REST
			pose.open = 1.0
		return pose
	var still := plan.pose(BuildPlan.SESSION if state == Session.State.BUILT else 0.0)
	if state == Session.State.IDLE or (state == Session.State.BUILT and planted):
		# Nothing on the planter: no plant yet, or it's out in the garden.
		still.placed = 0
	return still


## Lays out the plant's parts in build order, and the arm's plan to set
## each in its place.
func _lay_out() -> void:
	_pieces.clear()
	match kind:
		Parts.Kind.PIPE_VINE:
			_pipe_vine()
		Parts.Kind.GIRDER_REED:
			_girder_reed()
		Parts.Kind.SAIL_COTTON:
			_sail_cotton()
		Parts.Kind.KETTLE_GOURD:
			_kettle_gourd()
		_:
			_gear_flower()
	var spots: Array[Vector2] = []
	for piece: Piece in _pieces:
		spots.append(piece.spot)
	plan = BuildPlan.new(spots)


func _piece(shape: int, spot: Vector2, colour: Color, size := 0.0, reach := Vector2.ZERO, shine := true) -> void:
	var piece := Piece.new()
	piece.shape = shape
	piece.spot = spot
	piece.colour = colour
	piece.size = size
	piece.reach = reach
	piece.shine = shine
	_pieces.append(piece)


func _leaf(spot: Vector2, stem_x: float) -> void:
	_piece(LEAF, spot, BRASS.lerp(COPPER, 0.4), 0.0, Vector2(stem_x, spot.y + 8) - spot)


## The gear-flower: a jointed stem, its leaves, the gear's teeth round the
## head, then the hub.
func _gear_flower() -> void:
	for k in 6:
		_piece(BAR, Vector2(PLANT_X, GROUND - (k + 1) * 46.0), BRASS_DARK, 11.0, Vector2(0, 46))
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		_leaf(Vector2(PLANT_X + side * 44.0, GROUND - 70.0 - k * 50.0), PLANT_X)
	for k in 9:
		var ang := TAU * k / 9.0 - PI * 0.5
		_piece(PETAL, HEAD + Vector2(cos(ang), sin(ang)) * 50.0, BRASS.lightened(0.05))
	_piece(HUB, HEAD, BRASS, 30.0)


## The pipe-vine: copper tubing climbing in right-angled runs, a collar at
## each bend, leaves on the way and a valve wheel at the top.
func _pipe_vine() -> void:
	var pipe := COPPER
	var at := Vector2(PLANT_X, GROUND)
	var runs: Array[Vector2] = [Vector2(0, -52), Vector2(0, -52), Vector2(46, 0), Vector2(0, -50), Vector2(0, -50),
		Vector2(-46, 0), Vector2(-46, 0), Vector2(0, -50), Vector2(0, -50), Vector2(46, 0), Vector2(0, -48)]
	for k in runs.size():
		var to := at + runs[k]
		_piece(BAR, to, pipe, 13.0, at - to)
		# A collar where the run turns.
		if k + 1 < runs.size() and runs[k + 1].normalized() != runs[k].normalized():
			_piece(DISC, to, BRASS_DARK, 10.0)
		at = to
	_leaf(Vector2(PLANT_X - 46, GROUND - 78), PLANT_X)
	_leaf(Vector2(PLANT_X + 100, GROUND - 150), PLANT_X + 46)
	_leaf(Vector2(PLANT_X - 96, GROUND - 250), PLANT_X - 46)
	_piece(HUB, at + Vector2(0, -6), BRASS, 22.0)


## The girder-reed: a slender lattice mast of light alloy, two rails braced
## corner to corner, tapering to a brass tip.
func _girder_reed() -> void:
	var levels := 6
	var rise := 50.0
	for k in levels:
		var half := 20.0 - k * 2.2
		var above := 20.0 - (k + 1) * 2.2
		var low := GROUND - k * rise
		var high := low - rise
		_piece(BAR, Vector2(PLANT_X - above, high), ALLOY, 7.0, Vector2(above - half, rise))
		_piece(BAR, Vector2(PLANT_X + above, high), ALLOY, 7.0, Vector2(half - above, rise))
		var side := -1.0 if k % 2 == 0 else 1.0
		_piece(BAR, Vector2(PLANT_X + side * above, high), ALLOY.darkened(0.25), 4.0, Vector2(-side * (above + half), rise), false)
	_piece(BAR, Vector2(PLANT_X, GROUND - levels * rise - 34.0), ALLOY, 6.0, Vector2(0, 34))
	_piece(DISC, Vector2(PLANT_X, GROUND - levels * rise - 34.0), BRASS, 9.0)


## The sail-cotton: a brass stem and branches, a boll of cream cloth
## bursting at the end of each.
func _sail_cotton() -> void:
	var stem := BRASS_DARK
	for k in 5:
		_piece(BAR, Vector2(PLANT_X, GROUND - (k + 1) * 50.0), stem, 10.0, Vector2(0, 50))
	var tips: Array[Vector2] = [Vector2(-62, -110), Vector2(64, -150), Vector2(-58, -205), Vector2(56, -250)]
	for tip: Vector2 in tips:
		var root := Vector2(PLANT_X, GROUND + tip.y + 34.0)
		_piece(BAR, Vector2(PLANT_X, GROUND) + tip, stem, 6.0, root - (Vector2(PLANT_X, GROUND) + tip))
	tips.append(Vector2(0, -262))
	for tip: Vector2 in tips:
		var at := Vector2(PLANT_X, GROUND) + tip
		_piece(DISC, at, CANVAS.darkened(0.14), 24.0)
		_piece(DISC, at + Vector2(-5, -6), CANVAS.lightened(0.08), 16.0)


## The kettle-gourd: a short thick stalk under a copper drum built up in
## staves, banded and riveted in brass, with a cap and a curl of vine.
func _kettle_gourd() -> void:
	_piece(BAR, Vector2(PLANT_X, GROUND - 44), BRASS_DARK, 14.0, Vector2(0, 44))
	_piece(BAR, Vector2(PLANT_X, GROUND - 84), BRASS_DARK, 14.0, Vector2(0, 40))
	_leaf(Vector2(PLANT_X - 58, GROUND - 50), PLANT_X)
	_leaf(Vector2(PLANT_X + 58, GROUND - 62), PLANT_X)
	# The drum: five copper staves, widest in the middle, each held by its middle.
	var widths: Array[float] = [96.0, 124.0, 134.0, 124.0, 96.0]
	for k in widths.size():
		var y := GROUND - 100.0 - k * 30.0
		_piece(BAR, Vector2(PLANT_X, y), COPPER.darkened(0.08 * absf(k - 2.0)), 32.0, Vector2(widths[k], 0))
		_pieces[-1].centred = true
	for y: float in [GROUND - 115.0, GROUND - 205.0]:
		_piece(BAR, Vector2(PLANT_X, y), BRASS_DARK, 7.0, Vector2(124, 0), false)
		_pieces[-1].centred = true
	for k in 5:
		_piece(DISC, Vector2(PLANT_X - 48.0 + k * 24.0, GROUND - 160.0), BRASS, 4.5)
	_piece(BAR, Vector2(PLANT_X, GROUND - 262), BRASS_DARK, 22.0, Vector2(0, 26))
	_piece(DISC, Vector2(PLANT_X, GROUND - 266), BRASS, 12.0)
	_piece(BAR, Vector2(PLANT_X + 44, GROUND - 268), COPPER, 8.0, Vector2(-36, 14))
	_piece(DISC, Vector2(PLANT_X + 46, GROUND - 270), BRASS_DARK, 6.0)


## A steam vent: soft white puffs that rise, swell and fade.
func _steam(spot: Vector2, amount: int, life: float, spread: float) -> GPUParticles2D:
	var puff := GradientTexture2D.new()
	puff.width = 64
	puff.height = 64
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 0.9))
	soft.set_color(1, Color(1, 1, 1, 0.0))
	puff.gradient = soft
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.15, -1, 0)
	mat.spread = 14.0 * spread
	mat.initial_velocity_min = 38.0
	mat.initial_velocity_max = 62.0
	mat.gravity = Vector3(6, -22, 0)
	mat.damping_min = 8.0
	mat.damping_max = 14.0
	mat.scale_min = 0.5
	mat.scale_max = 0.9
	mat.scale_curve = grow_tex
	mat.color_ramp = ramp
	var vent := GPUParticles2D.new()
	vent.position = spot
	vent.amount = amount
	vent.lifetime = life
	vent.preprocess = life
	vent.texture = puff
	vent.process_material = mat
	add_child(vent)
	return vent


func _draw() -> void:
	if hangar == null or hangar.daylight == null:
		return
	var pose := _pose()
	_draw_boiler_live()
	_draw_plant(pose.placed)
	# The planter's front, after the plant: its foot is in the soil.
	box_front(320, 580, Machinery.PLANTER_HIGH, Machinery.PLANTER_DEEP, Machinery.TIMBER)
	for x: float in [322.0, 578.0]:
		line(Vector2(x, GROUND - Machinery.PLANTER_HIGH), Vector2(x, GROUND), lit(BRASS.darkened(0.1)), 4.0, Machinery.PLANTER_DEEP * 0.5)
	_draw_arm(pose)
	_draw_bin_front()


## The parts of the boiler that move: the firebox's flicker and the gauge's
## needle, which breathes with the work.
func _draw_boiler_live() -> void:
	# The fire burns only while the arm works.
	var fire := Color(1.0, 0.45 + 0.1 * sin(_t * 3.1), 0.12) if state == Session.State.BUILDING else Color(0.32, 0.12, 0.06)
	plate(73, Machinery.DOOR_TOP + 7, Machinery.DOOR_BOTTOM - 7, 43.5, Machinery.DOOR_HALF - 0.16, fire)
	var gauge := Vector2(73, 505)
	var needle := deg_to_rad(200.0 + 120.0 * (0.5 + 0.35 * sin(_t * 0.7)))
	line(gauge, gauge + Vector2(cos(needle), sin(needle)) * 13, Color(0.6, 0.1, 0.05), 2.0)


## The bin's front, over the arm: the gripper goes down behind it empty and
## comes up holding a part.
func _draw_bin_front() -> void:
	var left := Machinery.BIN_LEFT
	var right := Machinery.BIN_RIGHT
	var rim := GROUND - Machinery.BIN_HIGH
	var out := Machinery.BIN_DEEP * 0.5
	box_front(left, right, Machinery.BIN_HIGH, Machinery.BIN_DEEP, BRASS_DARK)
	line(Vector2(left, rim + 3), Vector2(right, rim + 3), lit(BRASS, _toward), 7.0, out)
	line(Vector2(left, GROUND - 4), Vector2(right, GROUND - 4), lit(BRASS_DARK.darkened(0.3), _toward), 6.0, out)
	for x: float in [left + 3, right - 3]:
		line(Vector2(x, rim), Vector2(x, GROUND), lit(BRASS.darkened(0.1), _toward), 5.0, out)


func _draw_plant(placed: int) -> void:
	for k in placed:
		_draw_part(k, plan.targets[k])


## Draws part k held or set at `where` (its spot, once on the plant).
func _draw_part(k: int, where: Vector2) -> void:
	var piece := _pieces[k]
	var colour := _tone(piece.colour)
	match piece.shape:
		BAR:
			if piece.centred:
				where -= piece.reach * 0.5
			line(where, where + piece.reach, colour.darkened(0.2), piece.size)
			if piece.shine:
				var side := piece.reach.normalized().orthogonal() * piece.size * 0.2
				if side.x + side.y > 0.0:
					side = -side
				line(where + side, where + piece.reach + side, colour.lightened(0.2), piece.size * 0.36)
		DISC:
			circle(where, piece.size, colour.darkened(0.25))
			circle(where, piece.size * 0.72, colour)
		LEAF:
			var root := where + piece.reach
			var leaf := PackedVector2Array([root, where.lerp(root, 0.5) + Vector2(0, -16), where, where.lerp(root, 0.5) + Vector2(0, 10)])
			polygon(leaf, colour)
			line(leaf[0], leaf[2], _tone(BRASS_DARK), 1.5)
		PETAL:
			var dir := (piece.spot - HEAD).normalized()
			var side := dir.orthogonal()
			var tooth := PackedVector2Array([where - dir * 16 + side * 13, where + dir * 8 + side * 8,
				where + dir * 8 - side * 8, where - dir * 16 - side * 13, where - dir * 16 + side * 13])
			polygon(tooth.slice(0, 4), colour)
			polyline(tooth, _tone(BRASS_DARK), 1.5)
		_:
			circle(where, piece.size, _tone(BRASS_DARK))
			circle(where, piece.size * 0.8, colour.lightened(0.1))
			circle(where, piece.size * 0.27, _tone(BRASS_DARK))


## Brass as it stands, or seized with rust on a plant left half-built.
func _tone(colour: Color) -> Color:
	return colour.lerp(RUST, 0.65) if state == Session.State.RUSTED else colour


## Two bones reaching so that the point between the jaws is at `target`,
## the elbow kept high; and the two pistons that work them, each pinned
## at both ends: pedestal to upper arm, upper arm to forearm.
func _limbs(target: Vector2) -> Limbs:
	var limbs := Limbs.new()
	var reach := FORE + GRIP
	var to := target - BASE
	var d := clampf(to.length(), absf(UPPER - reach) + 1.0, UPPER + reach - 1.0)
	var cos_a := (UPPER * UPPER + d * d - reach * reach) / (2.0 * UPPER * d)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var toward := to.normalized()
	var one := BASE + toward.rotated(a) * UPPER
	var two := BASE + toward.rotated(-a) * UPPER
	limbs.elbow = one if one.y < two.y else two
	limbs.dir = (target - limbs.elbow).normalized()
	limbs.wrist = limbs.elbow + limbs.dir * FORE
	limbs.shoulder = BASE + Vector2(0, -40)
	limbs.upper_foot = BASE + Vector2(44, -10)
	limbs.upper_end = limbs.shoulder.lerp(limbs.elbow, 0.55)
	# The forearm's piston is pinned to both bones, across the elbow's bend.
	limbs.fore_foot = limbs.shoulder.lerp(limbs.elbow, 0.45)
	limbs.fore_end = limbs.elbow + limbs.dir * 78.0
	return limbs


func _draw_arm(pose: BuildPlan.Pose) -> void:
	var limbs := _limbs(pose.tip)
	var shoulder := limbs.shoulder
	var elbow := limbs.elbow
	var wrist := limbs.wrist
	# Pedestal.
	polygon(PackedVector2Array([BASE + Vector2(-46, 0), BASE + Vector2(46, 0), BASE + Vector2(30, -40), BASE + Vector2(-30, -40)]), IRON)
	circle(shoulder, 26, BRASS_DARK)
	_bone(shoulder, elbow, 20.0)
	# A steam piston lifts the upper arm from the pedestal.
	_piston(limbs.upper_foot, limbs.upper_end, 12.0)
	_bone(elbow, wrist, 15.0)
	# And another, from the upper arm, swings the forearm about the elbow.
	_piston(limbs.fore_foot, limbs.fore_end, 9.0)
	_joint(shoulder, 22.0)
	_joint(elbow, 17.0)
	# The gripper: two jaws that open and close.
	var dir := limbs.dir
	var spread := 8.0 + 12.0 * pose.open
	for s: float in [-1.0, 1.0]:
		var root := wrist + dir.orthogonal() * s * 6.0
		var tip := wrist + dir * 26.0 + dir.orthogonal() * s * spread
		line(root, tip, BRASS_DARK, 6.0)
		line(tip, tip - dir.orthogonal() * s * 7.0 + dir * 4.0, BRASS_DARK, 5.0)
	_joint(wrist, 10.0)
	if pose.carrying >= 0:
		_draw_part(pose.carrying, wrist + dir * GRIP)


## A piston: its iron cylinder from the foot, the bright rod sliding out of
## it to the far end, a pin at each.
func _piston(foot: Vector2, end: Vector2, width: float) -> void:
	line(foot.lerp(end, 0.5), end, Color(0.80, 0.80, 0.78), width * 0.42)
	line(foot, foot.lerp(end, 0.55), IRON, width)
	circle(foot, width * 0.55, BRASS_DARK)
	circle(end, width * 0.5, BRASS_DARK)


func _bone(a: Vector2, b: Vector2, width: float) -> void:
	line(a, b, BRASS_DARK, width)
	var side := (b - a).normalized().orthogonal() * width * 0.22
	line(a + side, b + side, BRASS.lightened(0.2), width * 0.3)
	var n := int(a.distance_to(b) / 26.0)
	for k in range(1, n):
		circle(a.lerp(b, float(k) / n), 2.0, BRASS_DARK.darkened(0.4))


func _joint(spot: Vector2, r: float) -> void:
	circle(spot, r, BRASS_DARK)
	circle(spot, r * 0.72, BRASS)
	for k in 8:
		var ang := TAU * k / 8.0 + _t * 0.05
		circle(spot + Vector2(cos(ang), sin(ang)) * r * 0.86, r * 0.13, BRASS_DARK)
	circle(spot, r * 0.25, BRASS_DARK)

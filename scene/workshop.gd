extends "res://scene/corner_canvas.gd"
## The live part of the scene: the arm building the plant, the boiler's fire
## and gauge, the parts bin's front, the planter's front and the steam,
## stood on the hangar's floor (corner_canvas.gd). Redrawn every frame while
## the arm works.
##
## What it shows comes from the session alone (`state` and `progress`); the
## window redraws it only while the arm works.

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

enum { STEM, LEAF, PETAL, HUB }

var state := Session.State.IDLE
## How far through the session, 0 to 1.
var progress := 0.0
## Real seconds per second of the build plan: 1 for a full session, less for
## one shortened by AIRSHIP_SECONDS.
var time_scale := 1.0
var plan: BuildPlan

var _kinds: Array[int] = []
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
	plan = BuildPlan.new(_targets())
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
	if state == Session.State.IDLE:
		still.placed = 0
	return still


## The spots the arm sets each part, in build order: the stem from the
## ground up, its leaves, the gear's petals round the head, then the hub.
func _targets() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	_kinds.clear()
	for k in 6:
		spots.append(Vector2(PLANT_X, GROUND - (k + 1) * 46.0))
		_kinds.append(STEM)
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		spots.append(Vector2(PLANT_X + side * 44.0, GROUND - 70.0 - k * 50.0))
		_kinds.append(LEAF)
	for k in 9:
		var ang := TAU * k / 9.0 - PI * 0.5
		spots.append(HEAD + Vector2(cos(ang), sin(ang)) * 50.0)
		_kinds.append(PETAL)
	spots.append(HEAD)
	_kinds.append(HUB)
	return spots


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


## Draws part k with its build spot at `where`: on the plant, or in the gripper.
func _draw_part(k: int, where: Vector2) -> void:
	var spot := plan.targets[k]
	match _kinds[k]:
		STEM:
			line(where + Vector2(0, 46), where, _tone(BRASS_DARK), 11.0)
			line(where + Vector2(-2, 46), where + Vector2(-2, 0), _tone(BRASS).lightened(0.15), 4.0)
			circle(where, 7, _tone(BRASS_DARK))
		LEAF:
			var root := where + (Vector2(PLANT_X, spot.y + 8) - spot)
			var leaf := PackedVector2Array([root, where.lerp(root, 0.5) + Vector2(0, -16), where, where.lerp(root, 0.5) + Vector2(0, 10)])
			polygon(leaf, _tone(BRASS).lerp(_tone(COPPER), 0.4))
			line(leaf[0], leaf[2], _tone(BRASS_DARK), 1.5)
		PETAL:
			var dir := (spot - HEAD).normalized()
			var side := dir.orthogonal()
			var tooth := PackedVector2Array([where - dir * 16 + side * 13, where + dir * 8 + side * 8,
				where + dir * 8 - side * 8, where - dir * 16 - side * 13, where - dir * 16 + side * 13])
			polygon(tooth.slice(0, 4), _tone(BRASS).lightened(0.05))
			polyline(tooth, _tone(BRASS_DARK), 1.5)
		_:
			circle(where, 30, _tone(BRASS_DARK))
			circle(where, 24, _tone(BRASS).lightened(0.1))
			circle(where, 8, _tone(BRASS_DARK))


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

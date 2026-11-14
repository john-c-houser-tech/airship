extends Node2D
## The live part of the scene: the arm building the plant, the boiler's fire
## and gauge, the parts in the hopper, and the steam. Carried over from the
## milestone 3 prototype; milestone 5 replaces the art.
##
## What it shows comes from the session alone (`state` and `progress`); the
## window redraws it only while the arm works.

const BuildPlan := preload("res://scene/build_plan.gd")

const SIZE := 760.0
const BASE := Vector2(262, 640)
const UPPER := 235.0
const FORE := 225.0
const PLANT_X := 450.0
const GROUND := 640.0
const HEAD := Vector2(450, 318)
const VALVE := Vector2(72, 404)
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
var _piston_steam: GPUParticles2D


func _ready() -> void:
	plan = BuildPlan.new(_targets())
	_boiler_steam = _steam(VALVE, 26, 3.2, 0.9)
	_piston_steam = _steam(BASE + Vector2(48, -70), 18, 1.4, 1.3)
	show_session(state, progress)


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
	_piston_steam.emitting = working and pose.lifting
	queue_redraw()


## Real seconds the arm has rested, so the window knows when the steam has
## died away; 0 while it moves.
func resting_for() -> float:
	if state != Session.State.BUILDING:
		return INF
	return plan.rest_so_far(_t) * time_scale


func _pose() -> BuildPlan.Pose:
	if state == Session.State.BUILDING or state == Session.State.RUSTED:
		var pose := plan.pose(_t)
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
func _steam(at: Vector2, amount: int, life: float, spread: float) -> GPUParticles2D:
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
	vent.position = at
	vent.amount = amount
	vent.lifetime = life
	vent.preprocess = life
	vent.texture = puff
	vent.process_material = mat
	add_child(vent)
	return vent


func _draw() -> void:
	var pose := _pose()
	_draw_boiler_live()
	_draw_hopper(pose)
	_draw_plant(pose.placed)
	_draw_arm(pose)


## The parts of the boiler that move: the firebox's flicker and the gauge's
## needle, which breathes with the work.
func _draw_boiler_live() -> void:
	# The fire burns only while the arm works.
	var fire := Color(1.0, 0.45 + 0.1 * sin(_t * 3.1), 0.12) if state == Session.State.BUILDING else Color(0.32, 0.12, 0.06)
	draw_rect(Rect2(52, 596, 42, 18), fire)
	var gauge := Vector2(73, 505)
	var needle := deg_to_rad(200.0 + 120.0 * (0.5 + 0.35 * sin(_t * 0.7)))
	draw_line(gauge, gauge + Vector2(cos(needle), sin(needle)) * 13, Color(0.6, 0.1, 0.05), 2.0, true)


## A few parts left in the hopper, fewer as the plant grows.
func _draw_hopper(pose: BuildPlan.Pose) -> void:
	var left := maxi(0, 6 - (pose.placed >> 2))
	for k in left:
		draw_circle(Vector2(612 + k * 11, 476), 5, BRASS.lightened(0.1))


func _draw_plant(placed: int) -> void:
	for k in placed:
		_draw_part(k, plan.targets[k])


## Draws part k with its build spot at `at`: on the plant, or in the gripper.
func _draw_part(k: int, at: Vector2) -> void:
	var spot := plan.targets[k]
	match _kinds[k]:
		STEM:
			draw_line(at + Vector2(0, 46), at, _tone(BRASS_DARK), 11.0, true)
			draw_line(at + Vector2(-2, 46), at + Vector2(-2, 0), _tone(BRASS).lightened(0.15), 4.0, true)
			draw_circle(at, 7, _tone(BRASS_DARK))
		LEAF:
			var root := at + (Vector2(PLANT_X, spot.y + 8) - spot)
			var leaf := PackedVector2Array([root, at.lerp(root, 0.5) + Vector2(0, -16), at, at.lerp(root, 0.5) + Vector2(0, 10)])
			draw_colored_polygon(leaf, _tone(BRASS).lerp(_tone(COPPER), 0.4))
			draw_line(leaf[0], leaf[2], _tone(BRASS_DARK), 1.5, true)
		PETAL:
			var dir := (spot - HEAD).normalized()
			var side := dir.orthogonal()
			var tooth := PackedVector2Array([at - dir * 16 + side * 13, at + dir * 8 + side * 8,
				at + dir * 8 - side * 8, at - dir * 16 - side * 13, at - dir * 16 + side * 13])
			draw_colored_polygon(tooth.slice(0, 4), _tone(BRASS).lightened(0.05))
			draw_polyline(tooth, _tone(BRASS_DARK), 1.5, true)
		_:
			draw_circle(at, 30, _tone(BRASS_DARK))
			draw_circle(at, 24, _tone(BRASS).lightened(0.1))
			draw_circle(at, 8, _tone(BRASS_DARK))


## Brass as it stands, or seized with rust on a plant left half-built.
func _tone(colour: Color) -> Color:
	return colour.lerp(RUST, 0.65) if state == Session.State.RUSTED else colour


## Two bones reaching for the gripper's point, the elbow kept high.
func _elbow(target: Vector2) -> Vector2:
	var to := target - BASE
	var d := clampf(to.length(), absf(UPPER - FORE) + 1.0, UPPER + FORE - 1.0)
	var cos_a := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var dir := to.normalized()
	var one := BASE + dir.rotated(a) * UPPER
	var two := BASE + dir.rotated(-a) * UPPER
	return one if one.y < two.y else two


func _draw_arm(pose: BuildPlan.Pose) -> void:
	var elbow := _elbow(pose.tip)
	var wrist := elbow + (pose.tip - elbow).normalized() * FORE
	# Pedestal.
	draw_colored_polygon(PackedVector2Array([BASE + Vector2(-46, 0), BASE + Vector2(46, 0), BASE + Vector2(30, -40), BASE + Vector2(-30, -40)]), IRON)
	draw_circle(BASE + Vector2(0, -40), 26, BRASS_DARK)
	var shoulder := BASE + Vector2(0, -40)
	_bone(shoulder, elbow, 20.0)
	# A steam piston along the upper arm.
	var piston_root := BASE + Vector2(44, -10)
	var piston_end := shoulder.lerp(elbow, 0.55)
	draw_line(piston_root, piston_root.lerp(piston_end, 0.55), IRON, 12.0, true)
	draw_line(piston_root.lerp(piston_end, 0.5), piston_end, Color(0.80, 0.80, 0.78), 5.0, true)
	_bone(elbow, wrist, 15.0)
	_joint(shoulder, 22.0)
	_joint(elbow, 17.0)
	# The gripper: two jaws that open and close.
	var dir := (wrist - elbow).normalized()
	var spread := 8.0 + 12.0 * pose.open
	for s: float in [-1.0, 1.0]:
		var root := wrist + dir.orthogonal() * s * 6.0
		var tip := wrist + dir * 26.0 + dir.orthogonal() * s * spread
		draw_line(root, tip, BRASS_DARK, 6.0, true)
		draw_line(tip, tip - dir.orthogonal() * s * 7.0 + dir * 4.0, BRASS_DARK, 5.0, true)
	_joint(wrist, 10.0)
	if pose.carrying >= 0:
		_draw_part(pose.carrying, wrist + dir * 30.0)


func _bone(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, BRASS_DARK, width, true)
	var side := (b - a).normalized().orthogonal() * width * 0.22
	draw_line(a + side, b + side, BRASS.lightened(0.2), width * 0.3, true)
	var n := int(a.distance_to(b) / 26.0)
	for k in range(1, n):
		draw_circle(a.lerp(b, float(k) / n), 2.0, BRASS_DARK.darkened(0.4))


func _joint(at: Vector2, r: float) -> void:
	draw_circle(at, r, BRASS_DARK)
	draw_circle(at, r * 0.72, BRASS)
	for k in 8:
		var ang := TAU * k / 8.0 + _t * 0.05
		draw_circle(at + Vector2(cos(ang), sin(ang)) * r * 0.86, r * 0.13, BRASS_DARK)
	draw_circle(at, r * 0.25, BRASS_DARK)

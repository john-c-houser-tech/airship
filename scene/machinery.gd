extends "res://scene/corner_canvas.gd"
## The machinery that never moves: the planter, the boiler and the hopper's
## stand, standing on the hangar's floor and lit by its light. Drawn again
## only when the hangar is (the window asks); the arm, the plant and the
## planter's front, which must hide the plant's foot, are workshop.gd.

const GROUND := 640.0
const GAUGE := Vector2(73, 505)
const BRASS := Color(0.82, 0.60, 0.27)
const BRASS_DARK := Color(0.50, 0.33, 0.14)
const COPPER := Color(0.74, 0.42, 0.25)
const IRON := Color(0.24, 0.22, 0.21)
const TIMBER := Color(0.42, 0.28, 0.17)
## The planter: this tall in flat units, this deep in feet.
const PLANTER_HIGH := 16.0
const PLANTER_DEEP := 5.0


func _draw() -> void:
	if hangar == null or hangar.daylight == null:
		return
	_draw_shadow()
	_draw_planter()
	_draw_boiler()
	line(Vector2(610, GROUND), Vector2(618, 520), lit(IRON), 5.0)
	line(Vector2(672, GROUND), Vector2(664, 520), lit(IRON), 5.0)
	polygon(PackedVector2Array([Vector2(596, 470), Vector2(686, 470), Vector2(664, 522), Vector2(618, 522)]), lit(BRASS_DARK, _toward))
	polygon(PackedVector2Array([Vector2(600, 474), Vector2(682, 474), Vector2(678, 484), Vector2(604, 484)]), lit(Color(0.18, 0.13, 0.09)))


## A soft dark patch on the boards under the corner.
func _draw_shadow() -> void:
	var patch := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		var w := world(Vector2(MIDDLE, GROUND), 0.0) + _across * cos(t) * 21.0 + _toward * sin(t) * 6.0
		patch.append(_screen(w))
	draw_colored_polygon(patch, Color(0, 0, 0, 0.22 * (0.5 + 0.5 * hangar._day)))


## A brass boiler: a real cylinder, lit round, with its bands, rivets,
## firebox door, gauge, valve and the copper pipe to the arm on its face.
func _draw_boiler() -> void:
	cylinder(Vector2(73, GROUND), Vector2(73, 430), 43.0, BRASS)
	for y: float in [470.0, 540.0, 610.0]:
		band(73, y, 43.0, lit(BRASS_DARK.darkened(0.3)), lit(BRASS_DARK.darkened(0.4)))
	rect(Rect2(46, 590, 54, 30), lit(IRON))
	circle(GAUGE, 17, lit(Color(0.98, 0.95, 0.86), _toward))
	arc(GAUGE, 17, 0, TAU, lit(BRASS_DARK), 3.0)
	rect(Rect2(64, 416, 16, 14), lit(BRASS_DARK, Vector3.UP))
	var pipe := PackedVector2Array([Vector2(116, 560), Vector2(180, 560), Vector2(180, 612), Vector2(222, 612)])
	polyline(pipe, lit(COPPER.darkened(0.2)), 9.0)
	polyline(pipe, lit(COPPER.lightened(0.1), Vector3.UP), 3.0)


## The planter on the boards that the arm builds in: a low, open timber box
## of soil (its front, with the brass straps, is drawn by the workshop).
func _draw_planter() -> void:
	box(320, 580, PLANTER_HIGH, PLANTER_DEEP, TIMBER, Color(0.22, 0.15, 0.10))

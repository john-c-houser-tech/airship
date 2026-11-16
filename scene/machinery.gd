extends "res://scene/corner_canvas.gd"
## The machinery that never moves: the planter, the boiler and the parts
## bin, standing on the hangar's floor and lit by its light. Drawn again
## only when the hangar is (the window asks); the arm, the plant, the
## planter's front, which must hide the plant's foot, and the bin's front,
## which hides the gripper as it dips for a part, are workshop.gd.

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
## The parts bin, an open box on the floor: its ends, how tall it stands in
## flat units and how deep it is in feet.
const BIN_LEFT := 584.0
const BIN_RIGHT := 718.0
const BIN_HIGH := 98.0
const BIN_DEEP := 5.5
## The firebox door on the boiler: flat heights, and how far round it reaches.
const DOOR_TOP := 588.0
const DOOR_BOTTOM := 622.0
const DOOR_HALF := 0.72


func _draw() -> void:
	if hangar == null or hangar.daylight == null:
		return
	_draw_shadow()
	_draw_planter()
	_draw_boiler()
	_draw_bin()


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
	plate(73, DOOR_TOP, DOOR_BOTTOM, 43.0, DOOR_HALF, lit(IRON, _toward))
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


## The parts bin: an open brass-bound box on the floor, dark inside (its
## front is the workshop's, drawn over the arm, which reaches in from above).
func _draw_bin() -> void:
	box(BIN_LEFT, BIN_RIGHT, BIN_HIGH, BIN_DEEP, BRASS_DARK, Color(0.10, 0.08, 0.06))

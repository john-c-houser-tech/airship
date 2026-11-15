extends Node2D
## What the workshop corner's two layers share (machinery.gd, drawn when the
## light changes, and workshop.gd, redrawn while the arm moves): a plane
## standing on the hangar's floor in the left foreground, about sixty feet
## from the eye, turned a little so its left end lies farther off.
##
## The corner's art is laid out in its own flat coordinates (x right, y down,
## the floor at y = 640), as the milestone 3 prototype drew it. Every point
## is placed on the plane and seen through the hangar's camera, so the
## corner has the hangar's perspective; the drawing calls below take the
## flat coordinates and scale widths and radii for distance. Solid things
## (the boiler, the planter) are drawn as real 3D shapes, lit as the hangar
## lights its brass and timber.

const Hangar := preload("res://scene/hangar.gd")

## Feet per unit of the corner's flat coordinates.
const FEET := 0.053
## Where the corner stands: this far ahead of the eye and this far to its
## left, turned this much.
const AHEAD := 62.0
const LEFT := 19.0
const TURN := 15.0
const FLOOR_Y := 640.0
## The middle of the corner's art, across.
const MIDDLE := 350.0

var hangar: Hangar

var _origin := Vector3.ZERO
var _across := Vector3.RIGHT
var _toward := Vector3.BACK
# The hangar camera's angles, worked out once: the arm and plant are
# projected every frame while the arm works.
var _cos_yaw := 1.0
var _sin_yaw := 0.0
var _cos_pitch := 1.0
var _sin_pitch := 0.0


## Places the plane by the hangar's camera. Call once the hangar is ready.
func stand_in(hangar_: Hangar) -> void:
	hangar = hangar_
	var forward := Vector3(sin(hangar._yaw), 0, cos(hangar._yaw))
	var right := Vector3(cos(hangar._yaw), 0, -sin(hangar._yaw))
	_cos_yaw = cos(hangar._yaw)
	_sin_yaw = sin(hangar._yaw)
	_cos_pitch = cos(hangar._pitch)
	_sin_pitch = sin(hangar._pitch)
	var turn := deg_to_rad(TURN)
	_across = (right * cos(turn) - forward * sin(turn)).normalized()
	var centre := hangar._cam + forward * AHEAD - right * LEFT
	centre.y = 0.0
	# Out of the plane, toward the eye.
	_toward = _across.cross(Vector3.UP).normalized()
	if _toward.dot(hangar._cam - centre) < 0.0:
		_toward = -_toward
	_origin = centre - _across * (MIDDLE * FEET)
	queue_redraw()


## A point of the corner's flat art in the hangar's world, `out` feet toward
## the eye from the plane.
func world(p: Vector2, out := 0.0) -> Vector3:
	return _origin + _across * (p.x * FEET) + Vector3.UP * ((FLOOR_Y - p.y) * FEET) + _toward * out


## Where a point of the flat art lands on screen.
func at(p: Vector2) -> Vector2:
	return _screen(world(p))


## Screen pixels per unit of flat art, at a point.
func px(p: Vector2) -> float:
	return _seen(world(p)).z


func _screen(w: Vector3) -> Vector2:
	var seen := _seen(w)
	return Vector2(seen.x, seen.y)


## A world point as the hangar's camera sees it: screen x and y, and screen
## pixels per unit of flat art there. The corner always stands well in front
## of the eye (50 to 63 feet).
func _seen(w: Vector3) -> Vector3:
	var d := w - hangar._cam
	var x1 := d.x * _cos_yaw - d.z * _sin_yaw
	var z1 := d.x * _sin_yaw + d.z * _cos_yaw
	var y2 := d.y * _cos_pitch - z1 * _sin_pitch
	var z2 := maxf(d.y * _sin_pitch + z1 * _cos_pitch, Hangar.NEAR)
	var f: float = hangar._focal
	return Vector3(Hangar.SIZE * 0.5 + f * x1 / z2, Hangar.SIZE * 0.5 - f * y2 / z2, f * FEET / z2)


func _points(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(at(p))
	return out


## A line between two points of the flat art, `out` feet toward the eye.
func line(a: Vector2, b: Vector2, colour: Color, width: float, out := 0.0) -> void:
	var sa := _seen(world(a, out))
	var sb := _seen(world(b, out))
	draw_line(Vector2(sa.x, sa.y), Vector2(sb.x, sb.y), colour, maxf(width * (sa.z + sb.z) * 0.5, 0.6), true)


func circle(c: Vector2, r: float, colour: Color) -> void:
	var seen := _seen(world(c))
	draw_circle(Vector2(seen.x, seen.y), maxf(r * seen.z, 0.4), colour)


func polygon(points: PackedVector2Array, colour: Color) -> void:
	draw_colored_polygon(_points(points), colour)


func polyline(points: PackedVector2Array, colour: Color, width: float) -> void:
	var middle := points[points.size() >> 1]
	draw_polyline(_points(points), colour, maxf(width * px(middle), 0.6), true)


func rect(r: Rect2, colour: Color) -> void:
	polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), colour)


func arc(c: Vector2, r: float, from: float, to: float, colour: Color, width: float) -> void:
	var seen := _seen(world(c))
	draw_arc(Vector2(seen.x, seen.y), r * seen.z, from, to, 32, colour, maxf(width * seen.z, 0.6), true)


## Brass, iron or timber in the hangar's light: its ambient, the sun through
## the door, the lanterns, and the golden hour's warmth.
func lit(base: Color, normal := Vector3.ZERO) -> Color:
	var f := 0.55 * (0.4 + 0.6 * hangar._day) + 0.55 * maxf(normal.dot(hangar._light), 0.0) * (hangar._sun + hangar._moon) + 0.12
	var shaded := Color(base.r * f, base.g * f, base.b * f, base.a)
	return shaded.lerp(Color(hangar.daylight.warm, base.a), hangar.daylight.warmth * 0.2)


## An upright cylinder (the boiler) from flat point `bottom` to `top`, of
## radius `r` units, its body shaded round as light falls on it.
func cylinder(bottom: Vector2, top: Vector2, r: float, base: Color) -> void:
	var steps := 18
	var a := world(bottom)
	var b := world(top)
	var side := _across.cross(Vector3.UP).normalized()
	for k in steps:
		var t0 := TAU * k / steps
		var t1 := TAU * (k + 1) / steps
		var o0 := _across * cos(t0) + side * sin(t0)
		var o1 := _across * cos(t1) + side * sin(t1)
		var mid := (o0 + o1).normalized()
		if mid.dot(hangar._cam - (a + mid * r * FEET)) <= 0.0:
			continue
		var quad := PackedVector2Array([_screen(a + o0 * r * FEET), _screen(b + o0 * r * FEET),
			_screen(b + o1 * r * FEET), _screen(a + o1 * r * FEET)])
		# Round: brightest where it faces the light, and darker toward the
		# edges as the eye sees it, so it never reads as a flat panel.
		var view := (hangar._cam - a).normalized()
		var c0 := _shade_round(lit(base, o0), o0, view)
		var c1 := _shade_round(lit(base, o1), o1, view)
		draw_polygon(quad, PackedColorArray([c0, c0, c1, c1]))
	# The domed top, a disc as the eye sees it from a little above.
	var rim := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		rim.append(_screen(b + (_across * cos(t) + side * sin(t)) * r * FEET))
	draw_colored_polygon(rim, lit(base.darkened(0.15), Vector3.UP))


func _shade_round(colour: Color, normal: Vector3, view: Vector3) -> Color:
	var facing := clampf(normal.dot(view), 0.0, 1.0)
	var f := 0.55 + 0.6 * facing
	return Color(colour.r * f, colour.g * f, colour.b * f, colour.a)


## An open box on the floor (the planter): flat x from `left` to `right`,
## `high` units tall, `deep` feet from front to back, filled to its rim with
## `fill`; its fill and end shown. Its front is box_front(), drawn by the
## workshop after the plant, so the plant's foot is in the box.
func box(left: float, right: float, high: float, deep: float, base: Color, fill: Color) -> void:
	var front := deep * 0.5
	var back := -deep * 0.5
	var floor_y := FLOOR_Y
	var top_y := FLOOR_Y - high
	var top := PackedVector2Array([_screen(world(Vector2(left, top_y), back)), _screen(world(Vector2(right, top_y), back)),
		_screen(world(Vector2(right, top_y), front)), _screen(world(Vector2(left, top_y), front))])
	draw_colored_polygon(top, lit(base.darkened(0.1), Vector3.UP))
	var inner := PackedVector2Array([_screen(world(Vector2(left + 6, top_y + 2), back + 0.4)), _screen(world(Vector2(right - 6, top_y + 2), back + 0.4)),
		_screen(world(Vector2(right - 6, top_y + 2), front - 0.4)), _screen(world(Vector2(left + 6, top_y + 2), front - 0.4))])
	draw_colored_polygon(inner, lit(fill, Vector3.UP))
	var end := PackedVector2Array([_screen(world(Vector2(right, top_y), back)), _screen(world(Vector2(right, top_y), front)),
		_screen(world(Vector2(right, floor_y), front)), _screen(world(Vector2(right, floor_y), back))])
	draw_colored_polygon(end, lit(base.darkened(0.25), _across))


## The planter's front face, `deep` as in box().
func box_front(left: float, right: float, high: float, deep: float, base: Color) -> void:
	var front := deep * 0.5
	var floor_y := FLOOR_Y
	var top_y := FLOOR_Y - high
	var face := PackedVector2Array([_screen(world(Vector2(left, top_y), front)), _screen(world(Vector2(right, top_y), front)),
		_screen(world(Vector2(right, floor_y), front)), _screen(world(Vector2(left, floor_y), front))])
	draw_colored_polygon(face, lit(base, _toward))

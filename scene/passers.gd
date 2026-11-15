extends "res://scene/corner_canvas.gd"
## What passes outside, seen through the door while its sound plays: the
## night train along the railway across the valley, its chimney puffing
## steam, its headlamp lit after dark; and by day an airship crossing the sky.
## Drawn between the hangar's two pictures, so the door's frame and the
## airship in the hangar hide it as they should.
##
## Every frame comes from how far into its sound it is (the sound and its
## picture start together); nothing is carried from frame to frame.

## Seconds into the train's sound when it reaches the crossing (the sound's
## loudest, in tools/make_sounds.gd).
const TRAIN_AT_CROSSING := 26.0
## Feet a second: about forty miles an hour.
const TRAIN_SPEED := 60.0
const AIRSHIP_SPEED := 150.0
const AIRSHIP_HEIGHT := 900.0
const AIRSHIP_Z_BEYOND := 2600.0

## What is passing (Sounds.Kind), or -1 for nothing.
var kind := -1
## Seconds into its sound.
var seconds := 0.0


func show_passing(kind_: int, seconds_: float) -> void:
	kind = kind_
	seconds = seconds_
	queue_redraw()


## Whether anything is passing now (the window keeps drawing smoothly then).
func passing() -> bool:
	return kind >= 0 and seconds >= 0.0 and seconds <= float(Sounds.SECONDS[kind])


func _draw() -> void:
	if hangar == null or hangar.daylight == null or not passing():
		return
	if kind == Sounds.Kind.TRAIN:
		_draw_train()
	else:
		_draw_airship()


## A point in the world, on screen, with its scale in pixels per foot.
func _view(w: Vector3) -> Vector3:
	var seen := _seen(w)
	return Vector3(seen.x, seen.y, seen.z / FEET)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	var pa := _view(a)
	var pb := _view(b)
	var pc := _view(c)
	var pd := _view(d)
	draw_colored_polygon(PackedVector2Array([Vector2(pa.x, pa.y), Vector2(pb.x, pb.y), Vector2(pc.x, pc.y), Vector2(pd.x, pd.y)]), colour)


func _blob(w: Vector3, radius_feet: float, colour: Color) -> void:
	var p := _view(w)
	draw_circle(Vector2(p.x, p.y), maxf(radius_feet * p.z, 0.5), colour)


## The light outside: how bright things are in the valley.
func _outside_light() -> float:
	return 0.25 + 0.75 * hangar._day


## A colour darkened by the light outside, still opaque.
func _dim(c: Color, light: float) -> Color:
	return Color(c.r * light, c.g * light, c.b * light, c.a)


func _train_front(t: float) -> float:
	return hangar.crossing_x() + TRAIN_SPEED * (t - TRAIN_AT_CROSSING)


## A small steam train running left to right along the railway: the engine,
## its tender and three carriages, windows lit, steam from the chimney.
func _draw_train() -> void:
	var z: float = hangar.RAILWAY_Z
	var front := _train_front(seconds)
	var light := _outside_light()
	var iron := _dim(Color(0.16, 0.15, 0.15), light)
	var brass := _dim(Color(0.70, 0.52, 0.25), light)
	var carriage := _dim(Color(0.36, 0.14, 0.12), light)
	# The side facing the hangar.
	var side := z - 4.0
	# Carriages, tender, then the engine at the front.
	for k in 3:
		var back := front - 44.0 - 14.0 - (k + 1) * 34.0
		_quad(Vector3(back, 3, side), Vector3(back + 31, 3, side), Vector3(back + 31, 13, side), Vector3(back, 13, side), carriage)
		var glow := Color(1.0, 0.82, 0.48, 0.25 + 0.6 * (1.0 - hangar._day))
		for w in 5:
			var x := back + 3.0 + w * 6.0
			_quad(Vector3(x, 7, side - 0.2), Vector3(x + 3.5, 7, side - 0.2), Vector3(x + 3.5, 10.5, side - 0.2), Vector3(x, 10.5, side - 0.2), glow)
	var tender := front - 44.0 - 14.0
	_quad(Vector3(tender, 3, side), Vector3(tender + 12, 3, side), Vector3(tender + 12, 10, side), Vector3(tender, 10, side), iron)
	# The engine: boiler, cab, chimney, wheels.
	var engine := front - 44.0
	_quad(Vector3(engine + 12, 6, side), Vector3(front, 6, side), Vector3(front, 13, side), Vector3(engine + 12, 13, side), iron)
	_quad(Vector3(engine, 3, side), Vector3(engine + 13, 3, side), Vector3(engine + 13, 16, side), Vector3(engine, 16, side), iron)
	_quad(Vector3(front - 8, 13, side), Vector3(front - 5, 13, side), Vector3(front - 5, 18, side), Vector3(front - 8, 18, side), iron)
	_quad(Vector3(engine + 12, 9, side - 0.3), Vector3(front, 9, side - 0.3), Vector3(front, 10, side - 0.3), Vector3(engine + 12, 10, side - 0.3), brass)
	for w in 3:
		_blob(Vector3(engine + 16 + w * 9.0, 3, side - 0.4), 2.6, _dim(Color(0.5, 0.12, 0.08), light))
	# The headlamp, after dark.
	if hangar._day < 0.7:
		var lamp := _view(Vector3(front + 0.5, 9, side - 0.5))
		var strength := 1.0 - hangar._day
		draw_circle(Vector2(lamp.x, lamp.y), maxf(8.0 * lamp.z, 2.5), Color(1.0, 0.9, 0.6, 0.25 * strength))
		draw_circle(Vector2(lamp.x, lamp.y), maxf(2.0 * lamp.z, 1.0), Color(1.0, 0.95, 0.8, strength))
	# Steam: a puff every half second, rising and growing as it's left behind.
	for k in 14:
		var age := k * 0.5 + fmod(seconds, 0.5)
		var then := _train_front(seconds - age) - 6.5
		var puff := Vector3(then, 19.0 + age * 4.0, side)
		var alpha := clampf(0.7 - age * 0.1, 0.0, 0.7)
		if alpha > 0.0:
			_blob(puff, 2.5 + age * 2.2, Color(0.92 * light + 0.05, 0.92 * light + 0.05, 0.93 * light + 0.05, alpha))


## By day, an airship crossing the sky far off, right to left: a cream
## cloth hull, its gondola, fins and spinning propellers, and a thread of
## steam.
func _draw_airship() -> void:
	var duration := float(Sounds.SECONDS[Sounds.Kind.AIRSHIP])
	var x := AIRSHIP_SPEED * (duration * 0.5 - seconds)
	var z: float = hangar.DOOR_Z + AIRSHIP_Z_BEYOND
	var y := AIRSHIP_HEIGHT
	var light := _outside_light()
	var cloth := _dim(Color(0.88, 0.83, 0.70), light)
	var shade := _dim(Color(0.70, 0.65, 0.55), light)
	# The hull: an ellipse 240 by 56 feet, lit from above.
	var hull := PackedVector2Array()
	var colours := PackedColorArray()
	for k in 28:
		var t := TAU * k / 28.0
		var p := _view(Vector3(x + cos(t) * 120.0, y + sin(t) * 28.0, z))
		hull.append(Vector2(p.x, p.y))
		colours.append(cloth if sin(t) > 0.0 else shade)
	draw_polygon(hull, colours)
	for rib in range(-3, 4):
		var rx := x + rib * 30.0
		var top := _view(Vector3(rx, y + 27.0 * sqrt(maxf(0.0, 1.0 - pow(rib * 30.0 / 120.0, 2))), z - 1))
		var bottom := _view(Vector3(rx, y - 27.0 * sqrt(maxf(0.0, 1.0 - pow(rib * 30.0 / 120.0, 2))), z - 1))
		draw_line(Vector2(top.x, top.y), Vector2(bottom.x, bottom.y), _dim(Color(0.62, 0.48, 0.28, 0.6), light), 1.0, true)
	# Fins at the tail (on the right: it flies left).
	_quad(Vector3(x + 100, y + 10, z - 1), Vector3(x + 128, y + 26, z - 1), Vector3(x + 128, y + 4, z - 1), Vector3(x + 112, y, z - 1), shade)
	_quad(Vector3(x + 100, y - 10, z - 1), Vector3(x + 128, y - 26, z - 1), Vector3(x + 128, y - 4, z - 1), Vector3(x + 112, y, z - 1), shade)
	# The gondola, with its boiler's steam and two propellers spinning.
	var iron := _dim(Color(0.30, 0.20, 0.13), light)
	_quad(Vector3(x - 30, y - 34, z - 2), Vector3(x + 20, y - 34, z - 2), Vector3(x + 20, y - 44, z - 2), Vector3(x - 30, y - 44, z - 2), iron)
	for prop_x: float in [x - 36.0, x + 26.0]:
		var hub := _view(Vector3(prop_x, y - 39, z - 3))
		draw_circle(Vector2(hub.x, hub.y), maxf(9.0 * hub.z, 1.5), _dim(Color(0.85, 0.80, 0.70, 0.3), light))
	for k in 8:
		var age := k * 0.6 + fmod(seconds, 0.6)
		var puff := Vector3(x + 20 + age * AIRSHIP_SPEED * 0.9, y - 36 + age * 3.0, z - 2)
		var alpha := clampf(0.5 - age * 0.1, 0.0, 0.5)
		if alpha > 0.0:
			_blob(puff, 4.0 + age * 3.0, _dim(Color(0.95, 0.95, 0.96, alpha), light))

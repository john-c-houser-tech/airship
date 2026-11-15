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
## The train's chuffs in its sound (tools/make_sounds.gd): the first one's
## moment, and the seconds between them.
const CHUFFS_FROM := 1.5
const CHUFF_EVERY := 0.23
## Feet from the engine's front back to its chimney, and the chimney's top.
const CHIMNEY_BACK := 6.5
const CHIMNEY_TOP := 15.2
## The rails' top, where the wheels stand.
const RAIL := 1.5
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


## A box on the side of the train facing the hangar: from x0 to x1 along
## the track, y0 to y1 up, `out` feet nearer than the side.
func _panel(x0: float, x1: float, y0: float, y1: float, colour: Color, out := 0.0) -> void:
	var z: float = hangar.RAILWAY_Z - 5.0 - out
	var low := _view(Vector3(x0, y0, z))
	if (y1 - y0) * low.z < 1.0 or (x1 - x0) * low.z < 1.0:
		# Thinner than a pixel from here: a line, so it neither breaks into
		# pieces nor shimmers as the train moves.
		var a := _view(Vector3((x0 + x1) * 0.5 if x1 - x0 < y1 - y0 else x0, (y0 + y1) * 0.5 if x1 - x0 >= y1 - y0 else y0, z))
		var b := _view(Vector3((x0 + x1) * 0.5 if x1 - x0 < y1 - y0 else x1, (y0 + y1) * 0.5 if x1 - x0 >= y1 - y0 else y1, z))
		draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), colour, 1.0, true)
		return
	_quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), colour)


func _wheel(x: float, radius: float, colour: Color) -> void:
	_blob(Vector3(x, RAIL + radius, hangar.RAILWAY_Z - 5.4), radius, colour)


## A steam train running left to right along the railway, in the
## proportions of a ten-wheeler of the 1890s: a long boiler low over three
## tall driving wheels, a leading bogie under the smokebox, the cab behind,
## a tender half the engine's length and three long carriages, windows lit.
func _draw_train() -> void:
	var front := _train_front(seconds)
	var light := _outside_light()
	var iron := _dim(Color(0.15, 0.15, 0.16), light)
	var dark := _dim(Color(0.08, 0.08, 0.09), light)
	var brass := _dim(Color(0.72, 0.54, 0.26), light)
	var red := _dim(Color(0.45, 0.11, 0.08), light)
	var body := _dim(Color(0.34, 0.13, 0.11), light)
	var roof := _dim(Color(0.20, 0.19, 0.19), light)
	var night := 1.0 - hangar._day
	var glow := Color(1.0, 0.82, 0.48, 0.25 + 0.65 * night)
	# Three carriages, each 58 feet on two bogies, a raised roof along the top.
	for k in 3:
		var head := front - 66.0 - k * 61.0
		var tail := head - 58.0
		_panel(tail + 1.0, head - 1.0, RAIL + 1.6, RAIL + 3.0, dark)
		for bogie: float in [tail + 6.0, tail + 11.0, head - 11.0, head - 6.0]:
			_wheel(bogie, 1.5, dark)
		_panel(tail, head, 4.4, 12.6, body)
		_panel(tail, head, 12.6, 13.4, roof)
		_panel(tail + 4.0, head - 4.0, 13.4, 14.1, roof)
		_panel(tail, head, 7.0, 7.4, brass, 0.2)
		for w in 12:
			var x := tail + 5.0 + w * 4.2
			_panel(x, x + 2.6, 8.2, 11.4, glow, 0.2)
	# The tender: a water tank on two bogies, coal heaped above.
	var tender := front - 40.0
	_panel(tender - 23.0, tender, RAIL + 1.6, 4.6, dark)
	for bogie: float in [tender - 20.0, tender - 15.5, tender - 7.5, tender - 3.0]:
		_wheel(bogie, 1.5, dark)
	_panel(tender - 24.0, tender, 4.6, 10.4, iron)
	_panel(tender - 21.0, tender - 4.0, 10.4, 11.3, dark)
	_panel(tender - 24.0, tender, 9.6, 10.0, brass, 0.2)
	# The engine. Frame and running board first.
	_panel(front - 37.0, front - 2.0, 4.6, 5.4, dark)
	# Pilot (the cowcatcher), sloping down ahead of the smokebox.
	var z: float = hangar.RAILWAY_Z - 5.0
	_quad(Vector3(front - 4.0, RAIL + 0.3, z), Vector3(front + 2.5, RAIL + 0.3, z),
		Vector3(front - 2.0, 5.0, z), Vector3(front - 4.0, 5.0, z), red)
	# Boiler: smokebox, three rings banded in brass, firebox under the cab.
	_panel(front - 28.0, front - 3.0, 5.6, 11.4, iron)
	_panel(front - 9.5, front - 3.0, 5.6, 11.4, dark)
	for band: float in [front - 9.5, front - 15.5, front - 21.5]:
		_panel(band - 0.3, band + 0.3, 5.6, 11.4, brass, 0.2)
	# Chimney with its flared cap, then the sand dome and the steam dome.
	_panel(front - CHIMNEY_BACK - 0.9, front - CHIMNEY_BACK + 0.9, 11.4, CHIMNEY_TOP - 0.6, dark)
	_panel(front - CHIMNEY_BACK - 1.4, front - CHIMNEY_BACK + 1.4, CHIMNEY_TOP - 0.6, CHIMNEY_TOP, dark)
	_blob(Vector3(front - 13.0, 11.6, z - 0.2), 1.3, iron)
	_blob(Vector3(front - 19.5, 12.3, z - 0.2), 1.5, brass)
	# Cab: taller than the boiler, its roof overhanging the tender, a window.
	_panel(front - 37.0, front - 28.0, 5.4, 13.2, iron)
	_panel(front - 39.0, front - 27.2, 13.2, 13.9, roof)
	_panel(front - 35.5, front - 30.5, 9.4, 12.2, Color(1.0, 0.62, 0.30, 0.2 + 0.6 * night), 0.2)
	# Cylinder beside the smokebox, over the leading bogie's small wheels.
	for bogie: float in [front - 5.0, front - 10.5]:
		_wheel(bogie, 1.5, dark)
	_panel(front - 10.5, front - 5.5, 3.4, 5.6, iron, 0.5)
	# Three driving wheels as tall as a man, red, turning; the rod that
	# couples them rides round with their cranks.
	var drivers: Array[float] = [front - 16.0, front - 22.3, front - 28.6]
	for driver: float in drivers:
		_wheel(driver, 2.95, red)
		_blob(Vector3(driver, RAIL + 2.95, z - 0.5), 0.8, dark)
	var turn := front / 2.95
	var crank := Vector3(cos(turn) * 1.5, RAIL + 2.95 - sin(turn) * 1.5, z - 0.7)
	var rod_back := _view(Vector3(drivers[2] + crank.x, crank.y, crank.z))
	var rod_front := _view(Vector3(drivers[0] + crank.x, crank.y, crank.z))
	var piston := _view(Vector3(front - 10.0, 4.5, crank.z))
	var steel := _dim(Color(0.62, 0.62, 0.64), light)
	draw_line(Vector2(rod_back.x, rod_back.y), Vector2(rod_front.x, rod_front.y), steel, maxf(0.5 * rod_back.z, 1.0), true)
	draw_line(Vector2(rod_front.x, rod_front.y), Vector2(piston.x, piston.y), steel, maxf(0.4 * rod_back.z, 1.0), true)
	# The headlamp on the smokebox, after dark.
	_panel(front - 4.0, front - 2.6, 11.4, 12.8, brass)
	if hangar._day < 0.7:
		var lamp := _view(Vector3(front - 2.4, 12.1, z - 0.5))
		draw_circle(Vector2(lamp.x, lamp.y), maxf(8.0 * lamp.z, 2.5), Color(1.0, 0.9, 0.6, 0.25 * night))
		draw_circle(Vector2(lamp.x, lamp.y), maxf(1.6 * lamp.z, 1.0), Color(1.0, 0.95, 0.8, night))
	_draw_exhaust(light)


## A number from 0 to 1 that belongs to `n`: the same every frame.
func _chance(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 4.1) * 43758.5453, 1.0)


## The engine's exhaust, like the boiler's steam in the hangar: two hundred
## small soft wisps, thrown up hard from the chimney in beats with the
## chuffs, then slowing, spreading, thinning and trailing back over the
## train. Each wisp is found from when it left the chimney, so the plume is
## the same whenever the frame is drawn.
func _draw_exhaust(light: float) -> void:
	var every := 0.045
	var newest := floorf(seconds / every)
	var z: float = hangar.RAILWAY_Z - 5.0
	for k in 200:
		var born := (newest - k) * every
		var age := seconds - born
		var a := _chance(newest - k)
		var b := _chance((newest - k) * 1.7 + 9.0)
		# In time with the sound's chuffs: thick at each, thin between.
		var beat := 0.35 + 0.65 * pow(0.5 + 0.5 * cos(TAU * (born - CHUFFS_FROM) / CHUFF_EVERY), 2.0)
		var fade := exp(-age * 0.42) * minf(1.0, age * 8.0 + 0.3)
		var alpha := 0.34 * beat * fade * (0.6 + 0.4 * b)
		if alpha < 0.012:
			continue
		var x := _train_front(born) - CHIMNEY_BACK + (a - 0.5) * (1.0 + age * 2.6) - age * 2.0
		var y := CHIMNEY_TOP + 9.0 * (1.0 - exp(-age * 1.5)) * (0.7 + 0.6 * b) + age * (1.2 + 1.6 * a)
		var radius := 0.9 + 2.3 * pow(age, 0.75) * (0.6 + 0.8 * a)
		# Sooty at the chimney, white once it has cooled.
		var white := clampf(age * 1.2, 0.0, 1.0)
		var shade := lerpf(0.42, 0.93, white) * light + 0.04
		var at := _view(Vector3(x, y, z))
		var size := maxf(radius * at.z, 0.5)
		# A denser heart, where the wisp is big enough to show one.
		if size > 3.0:
			draw_circle(Vector2(at.x, at.y), size, Color(shade, shade, shade + 0.01, alpha))
			draw_circle(Vector2(at.x, at.y), size * 0.55, Color(shade, shade, shade + 0.01, alpha))
		else:
			draw_circle(Vector2(at.x, at.y), size, Color(shade, shade, shade + 0.01, minf(alpha * 1.6, 1.0)))


## By day, an airship crossing the sky far off, right to left, with a
## thread of steam.
func _draw_airship() -> void:
	var duration := float(Sounds.SECONDS[Sounds.Kind.AIRSHIP])
	var x := AIRSHIP_SPEED * (duration * 0.5 - seconds)
	_draw_ship(Vector3(x, AIRSHIP_HEIGHT, hangar.DOOR_Z + AIRSHIP_Z_BEYOND), 1.0, -1.0, AIRSHIP_SPEED)


## An airship side on, its middle at `centre`, `size` times the far one's
## 240 feet, its nose to the right (`facing` 1) or the left (-1): a cream
## cloth hull and fins, its gondola, the steam engine and propeller behind
## it, the stack's exhaust left behind at `speed` feet a second.
func _draw_ship(centre: Vector3, size: float, facing: float, speed: float) -> void:
	var x := centre.x
	var y := centre.y
	var z := centre.z
	# Along the ship toward its tail, and its scale.
	var back := -facing * size
	var up := size
	var light := _outside_light()
	var cloth := _dim(Color(0.88, 0.83, 0.70), light)
	var shade := _dim(Color(0.70, 0.65, 0.55), light)
	# The hull: an ellipse 240 by 56 feet, lit from above.
	var hull := PackedVector2Array()
	var colours := PackedColorArray()
	for k in 28:
		var t := TAU * k / 28.0
		var p := _view(Vector3(x + cos(t) * 120.0 * size, y + sin(t) * 28.0 * up, z))
		hull.append(Vector2(p.x, p.y))
		colours.append(cloth if sin(t) > 0.0 else shade)
	draw_polygon(hull, colours)
	for rib in range(-3, 4):
		var rx := x + rib * 30.0 * size
		var half := 27.0 * up * sqrt(maxf(0.0, 1.0 - pow(rib * 30.0 / 120.0, 2)))
		var top := _view(Vector3(rx, y + half, z - 1))
		var bottom := _view(Vector3(rx, y - half, z - 1))
		draw_line(Vector2(top.x, top.y), Vector2(bottom.x, bottom.y), _dim(Color(0.62, 0.48, 0.28, 0.6), light), 1.0, true)
	# Fins at the tail.
	_quad(Vector3(x + 100 * back, y + 10 * up, z - 1), Vector3(x + 128 * back, y + 26 * up, z - 1),
		Vector3(x + 128 * back, y + 4 * up, z - 1), Vector3(x + 112 * back, y, z - 1), shade)
	_quad(Vector3(x + 100 * back, y - 10 * up, z - 1), Vector3(x + 128 * back, y - 26 * up, z - 1),
		Vector3(x + 128 * back, y - 4 * up, z - 1), Vector3(x + 112 * back, y, z - 1), shade)
	# Struts down to the gondola and the engine car behind it.
	var iron := _dim(Color(0.30, 0.20, 0.13), light)
	var dark := _dim(Color(0.14, 0.12, 0.11), light)
	var copper := _dim(Color(0.74, 0.42, 0.25), light)
	var brass := _dim(Color(0.80, 0.58, 0.26), light)
	for strut: float in [-26.0, -6.0, 14.0, 34.0, 58.0]:
		var top := _view(Vector3(x + strut * back, y - 26 * up, z - 1))
		var foot := _view(Vector3(x + (strut + 2.0) * back, y - 35 * up, z - 2))
		draw_line(Vector2(top.x, top.y), Vector2(foot.x, foot.y), dark, maxf(0.8 * size * top.z, 1.0), true)
	# The gondola: a timber car with a row of windows.
	_quad(Vector3(x - 32 * back, y - 34 * up, z - 2), Vector3(x + 20 * back, y - 34 * up, z - 2),
		Vector3(x + 20 * back, y - 44 * up, z - 2), Vector3(x - 26 * back, y - 44 * up, z - 2), iron)
	for w in 5:
		var wx := -24.0 + w * 8.0
		_quad(Vector3(x + wx * back, y - 36.5 * up, z - 3), Vector3(x + (wx + 4.5) * back, y - 36.5 * up, z - 3),
			Vector3(x + (wx + 4.5) * back, y - 40 * up, z - 3), Vector3(x + wx * back, y - 40 * up, z - 3),
			Color(1.0, 0.85, 0.55, 0.35 + 0.5 * (1.0 - hangar._day)))
	# The steam engine behind it: a copper boiler banded in brass, its
	# firebox, and a stack raked back.
	_quad(Vector3(x + 24 * back, y - 33 * up, z - 2), Vector3(x + 58 * back, y - 33 * up, z - 2),
		Vector3(x + 58 * back, y - 45 * up, z - 2), Vector3(x + 24 * back, y - 45 * up, z - 2), copper)
	_blob(Vector3(x + 58 * back, y - 39 * up, z - 2), 6.0 * size, copper)
	_blob(Vector3(x + 24 * back, y - 39 * up, z - 2), 6.0 * size, dark)
	for band: float in [32.0, 42.0, 52.0]:
		_quad(Vector3(x + band * back, y - 33 * up, z - 3), Vector3(x + (band + 1.4) * back, y - 33 * up, z - 3),
			Vector3(x + (band + 1.4) * back, y - 45 * up, z - 3), Vector3(x + band * back, y - 45 * up, z - 3), brass)
	var stack := Vector3(x + 50 * back, y - 31 * up, z - 2)
	var stack_top := Vector3(x + 60 * back, y - 22 * up, z - 2)
	var st := _view(stack)
	var sp := _view(stack_top)
	draw_line(Vector2(st.x, st.y), Vector2(sp.x, sp.y), dark, maxf(3.4 * size * st.z, 1.5), true)
	# The propeller at the engine's tail, seen edge on as it spins: a blur
	# the height of its sweep, and the blades flashing through it.
	var hub := Vector3(x + 68 * back, y - 39 * up, z - 3)
	var shaft_from := _view(Vector3(x + 60 * back, y - 39 * up, z - 3))
	var h := _view(hub)
	draw_line(Vector2(shaft_from.x, shaft_from.y), Vector2(h.x, h.y), dark, maxf(1.6 * size * h.z, 1.0), true)
	var sweep := 13.0 * size * h.z
	var blur := PackedVector2Array()
	for k in 16:
		var t := TAU * k / 16.0
		blur.append(Vector2(h.x + cos(t) * maxf(sweep * 0.16, 1.0), h.y + sin(t) * sweep))
	draw_colored_polygon(blur, _dim(Color(0.80, 0.74, 0.62, 0.35), light))
	var blade := sweep * absf(cos(seconds * 19.0))
	draw_line(Vector2(h.x, h.y - blade), Vector2(h.x, h.y + blade), _dim(Color(0.45, 0.33, 0.20), light), maxf(1.4 * size * h.z, 1.0), true)
	draw_circle(Vector2(h.x, h.y), maxf(1.8 * size * h.z, 1.0), brass)
	# The stack's exhaust, like the train's: small wisps, sooty as they
	# leave, whitening, spreading and thinning as they are left behind.
	var every := 0.07
	var newest := floorf(seconds / every)
	for k in 90:
		var born := (newest - k) * every
		var age := seconds - born
		var a := _chance(newest - k)
		var b := _chance((newest - k) * 1.7 + 9.0)
		var beat := 0.5 + 0.5 * pow(0.5 + 0.5 * cos(TAU * born * 1.6), 2.0)
		var alpha := 0.36 * beat * exp(-age * 0.55) * minf(1.0, age * 6.0 + 0.3) * (0.6 + 0.4 * b)
		if alpha < 0.012:
			continue
		var trail := age * speed * 0.9 + (a - 0.5) * (1.0 + age * 3.0) * size
		var rise := (4.0 * (1.0 - exp(-age * 1.4)) + age * (0.8 + 1.4 * a)) * size
		var at := _view(stack_top + Vector3(-facing * trail, rise, 0))
		var white := clampf(age * 1.1, 0.0, 1.0)
		var tone := lerpf(0.40, 0.94, white) * light + 0.04
		draw_circle(Vector2(at.x, at.y), maxf((1.0 + 2.6 * pow(age, 0.75) * (0.6 + 0.8 * a)) * size * at.z, 0.5),
			Color(tone, tone, tone + 0.01, alpha))

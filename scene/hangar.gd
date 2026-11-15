extends Node2D
## The scene: inside the big timber hangar, beside the airship's front third,
## looking out through the door at the valley, the garden and the mountains.
## Grown from the milestone 2 mock-up (decided at gate B, and again after the
## milestone 5 mock-ups).
##
## The hangar, the airship and the land are 3D points seen through one
## perspective camera and drawn flat, back to front (the painter's way). No
## textures, no shaders: gradients come from per-corner colours. What it
## shows comes from the core: the daylight, the weather, how far the airship
## is built and how many plants stand in the garden. It draws only when one
## of those changes, never every frame.

const SIZE := 760.0
const NEAR := 1.0

# The hangar, in feet: x across, y up, z from the back towards the doors.
const HALF_W := 150.0
const HANGAR_H := 190.0
const DOOR_Z := 640.0
const DOOR_HALF_W := 128.0
const DOOR_H := 150.0
const RIB_STEP := 48.0
const ARCH_STEPS := 40

# The airship: local z runs tail (-) to nose (+).
const SHIP_L := 300.0
const SHIP_R := 34.0
const STATIONS := 24
const LONGERONS := 24
## The ship is modelled small and drawn this many times bigger.
const SHIP_SCALE := 1.7
const SHIP_ORIGIN := Vector3(40, 92, 330)

# Light comes in through the doors, from the sun low on the left.

const BRASS := Color(0.80, 0.58, 0.26)
const COPPER := Color(0.74, 0.42, 0.25)
const ALLOY := Color(0.70, 0.72, 0.74)
const CANVAS := Color(0.88, 0.83, 0.70)
const WOOD := Color(0.36, 0.24, 0.15)
const WOOD_DARK := Color(0.17, 0.11, 0.07)
const CONCRETE := Color(0.40, 0.29, 0.19)

## How much of the airship is built, 0 to 1.
var built := 0.0
## The light: the sky's colours, the sun or moon, how bright the day is.
var daylight: Daylight
## The weather outside: cloud, rain, fog and snow.
var conditions := Weather.Conditions.new()
## The kinds (Parts.Kind) of the built plants in the garden, oldest first.
var garden_plants: Array[int] = []
## While the arm works, rain and snow are drawn moving (scene/falling.gd)
## instead of still here.
var moving_weather := false
## Which part this one paints: the window keeps the outside (sky, clouds,
## land, railway) and the inside (the garden, rain, snow and fog, the hangar
## and the airship, clear where the door shows the outside) as two pictures,
## so a train or an airship passing goes between them: behind the door's
## frame, the ship, the garden and the weather. ALL paints both, in order.
## While the arm works, rain and snow move instead (scene/falling.gd, also
## between the pictures), and the inside paints them only when still.
enum Painting { ALL, OUTSIDE, INSIDE }
var painting := Painting.ALL
## The railway across the valley: this far beyond the door.
const RAILWAY_Z := DOOR_Z + 350.0
## Where the near hills start to rise beyond the door, and where they crest.
const HILLS_FOOT := 520.0
const HILLS_CREST := 2400.0
# How strongly the sun shines in, 0 to 1: up, high enough, not clouded over.
var _sun := 1.0
# How bright the day is outside, 0 (night) to 1, from the daylight.
var _day := 1.0
# How much the moon lights things, 0 to a quarter.
var _moon := 0.0
## Shows the finished ship outside, climbing towards the pass.
## The finished airship out over the valley (milestone 7 sets this; the
## pose, the blurred propellers and the smoke trail are ready for it).
var launched := false

var _cam := Vector3(-95, 20, 300)
var _yaw := deg_to_rad(19.0)
var _pitch := deg_to_rad(9.0)
var _focal := 0.0
var _light := Vector3.ZERO

# The ship's pose: inside on its cradles, or out over the valley.
var _ship_basis := Basis.IDENTITY
var _ship_origin := SHIP_ORIGIN

# Build order, worked out once: each part's share of the whole job.
var _parts: Array[Part] = []
var _total_cost := 0.0


class Part:
	var kind: int
	var i: int
	var j: int
	var cost: float

	func _init(kind_: int, i_: int, j_: int, cost_: float) -> void:
		kind = kind_
		i = i_
		j = j_
		cost = cost_


class Item:
	var depth: float
	var draw: Callable

	func _init(depth_: float, draw_: Callable) -> void:
		depth = depth_
		draw = draw_


enum { KEEL, RING, LONGERON, GONDOLA, ENGINE, FIN, CLOTH }


func _ready() -> void:
	_focal = SIZE * 0.5 / tan(deg_to_rad(62.0) * 0.5)
	_plan_build()


## Shows the light and weather, how far the airship is built, and the
## plants that stand in the garden. Draws again only for these, and says whether
## it will (the window keeps the hangar as a picture, remade only then).
func show_world(daylight_: Daylight, conditions_: Weather.Conditions, built_: float, garden_plants_: Array[int], moving := false) -> bool:
	moving_weather = moving
	daylight = daylight_
	conditions = conditions_
	built = clampf(built_, 0.0, 1.0)
	garden_plants = garden_plants_
	_follow_light()
	# Drawing the hangar takes tens of milliseconds, enough to make the arm
	# stutter: only when the picture would change enough to see.
	var seen := _what_shows()
	if seen == _shown:
		return false
	_shown = seen
	queue_redraw()
	return true


# What the last drawing showed, coarsely, to tell when to draw again.
var _shown := ""


func _what_shows() -> String:
	var steps := func(v: float, n: float) -> int: return roundi(v * n)
	return "%d %d %d %d %d %d %d %d %s %s %s" % [steps.call(_day, 40.0), steps.call(_sun, 20.0),
		steps.call(daylight.stars, 10.0), steps.call(daylight.warmth, 20.0),
		steps.call(conditions.cloud, 40.0), steps.call(conditions.rain, 10.0), steps.call(conditions.fog, 10.0),
		steps.call(conditions.snow, 10.0), str(garden_plants), daylight.top.to_html(false).left(5), str(built)] \
		+ " %d %d %s" % [steps.call(daylight.sun_x, 40.0), steps.call(daylight.moon_x, 40.0), str(moving_weather)]


## Where the light comes from: the sun across the door's view by day, the
## moon by night (dimly), and how strongly it reaches in.
func _follow_light() -> void:
	var across := daylight.sun_x if daylight.sun_up else daylight.moon_x
	var height := daylight.elevation if daylight.sun_up else maxf(daylight.moon_elevation, 0.0) * 0.5
	var az := deg_to_rad(lerpf(-55.0, 55.0, across))
	var el := deg_to_rad(4.0 + 50.0 * clampf(height, 0.0, 1.0))
	_light = Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	# Cloud and fog dim the day as well as hiding the sun.
	_day = clampf((daylight.ambient - 0.22) / 0.78, 0.0, 1.0) * (1.0 - 0.3 * conditions.cloud) * (1.0 - 0.2 * conditions.fog)
	_sun = (clampf(daylight.elevation * 4.0, 0.0, 1.0) if daylight.sun_up else 0.0) * (1.0 - 0.8 * conditions.cloud) * (1.0 - 0.7 * conditions.fog)
	# A clear night's moon gives a faint light of its own.
	_moon = (0.0 if daylight.sun_up else clampf(daylight.moon_elevation, 0.0, 1.0) * 0.25) * (1.0 - conditions.cloud)


# ---------------------------------------------------------------- the camera

func _to_cam(p: Vector3) -> Vector3:
	var d := p - _cam
	var x1 := d.x * cos(_yaw) - d.z * sin(_yaw)
	var z1 := d.x * sin(_yaw) + d.z * cos(_yaw)
	var y2 := d.y * cos(_pitch) - z1 * sin(_pitch)
	var z2 := d.y * sin(_pitch) + z1 * cos(_pitch)
	return Vector3(x1, y2, z2)


func _project(c: Vector3) -> Vector2:
	return Vector2(SIZE * 0.5 + _focal * c.x / c.z, SIZE * 0.5 - _focal * c.y / c.z)


func _depth(p: Vector3) -> float:
	return _to_cam(p).z


## Fills a flat convex polygon given in world points, one colour per corner,
## cut where it passes behind the camera.
func _poly(points: Array[Vector3], colours: Array[Color]) -> void:
	var cam: Array[Vector3] = []
	for p: Vector3 in points:
		cam.append(_to_cam(p))
	var out_p := PackedVector2Array()
	var out_c := PackedColorArray()
	var n := cam.size()
	for k in n:
		var a := cam[k]
		var b := cam[(k + 1) % n]
		var ca := colours[k % colours.size()]
		var cb := colours[(k + 1) % n % colours.size()]
		if a.z >= NEAR:
			out_p.append(_project(a))
			out_c.append(ca)
		if (a.z >= NEAR) != (b.z >= NEAR):
			var t := (NEAR - a.z) / (b.z - a.z)
			out_p.append(_project(a.lerp(b, t)))
			out_c.append(ca.lerp(cb, t))
	_fan(out_p, out_c)


## Fills a convex screen polygon as a fan of triangles (no triangulation, so
## a sliver never makes Godot complain).
func _fan(points: PackedVector2Array, colours: PackedColorArray) -> void:
	if points.size() < 3:
		return
	var idx := PackedInt32Array()
	for k in range(1, points.size() - 1):
		idx.append(0)
		idx.append(k)
		idx.append(k + 1)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, points, colours)


func _flat(points: Array[Vector3], colour: Color) -> void:
	_poly(points, [colour])


## A beam between two world points, as wide as `width` feet at each end.
func _beam(a: Vector3, b: Vector3, width: float, colour: Color, shine: Color) -> void:
	var ca := _to_cam(a)
	var cb := _to_cam(b)
	if ca.z < NEAR and cb.z < NEAR:
		return
	if ca.z < NEAR:
		ca = cb.lerp(ca, (cb.z - NEAR) / (cb.z - ca.z))
	elif cb.z < NEAR:
		cb = ca.lerp(cb, (ca.z - NEAR) / (ca.z - cb.z))
	var pa := _project(ca)
	var pb := _project(cb)
	var along := pb - pa
	if along.length() < 0.01:
		return
	var side := Vector2(-along.y, along.x).normalized()
	var wa := maxf(_focal * width / ca.z * 0.5, 0.35)
	var wb := maxf(_focal * width / cb.z * 0.5, 0.35)
	_fan(PackedVector2Array([pa + side * wa, pb + side * wb, pb - side * wb, pa - side * wa]),
		_same(colour, 4))
	if shine.a > 0.0 and wa > 0.9:
		var hs := 0.35
		_fan(PackedVector2Array([pa + side * wa * 0.75, pb + side * wb * 0.75,
				pb + side * wb * hs, pa + side * wa * hs]),
			PackedColorArray([shine, shine, shine, shine]))


func _glow(centre: Vector2, radius: float, colour: Color) -> void:
	var pts := PackedVector2Array([centre])
	var cols := PackedColorArray([colour])
	var edge := Color(colour, 0.0)
	for k in 25:
		var ang := TAU * k / 24.0
		pts.append(centre + Vector2(cos(ang), sin(ang)) * radius)
		cols.append(edge)
	_fan(pts, cols)


func _disc(centre: Vector2, radius: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var ang := TAU * k / 20.0
		pts.append(centre + Vector2(cos(ang), sin(ang)) * radius)
	_fan(pts, _same(colour, 20))


func _same(colour: Color, n: int) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(n)
	cols.fill(colour)
	return cols


## A colour under more or less light, as solid as it was (Color * float
## would thin it, and the stars would shine through the mountains).
func _shade(base: Color, f: float) -> Color:
	return Color(base.r * f, base.g * f, base.b * f, base.a)


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	if daylight == null:
		return
	if launched:
		_ship_basis = Basis(Vector3.UP, deg_to_rad(64.0)) * Basis(Vector3.RIGHT, deg_to_rad(-7.0))
		_ship_origin = Vector3(150, 330, DOOR_Z + 1500)
	else:
		_ship_basis = Basis.IDENTITY
		_ship_origin = SHIP_ORIGIN
	if painting != Painting.INSIDE:
		_draw_sky()
		_draw_land()
		_draw_clouds()
		if launched:
			var outside := _ship_items(1.0)
			outside.sort_custom(func(a: Item, b: Item) -> bool: return a.depth > b.depth)
			for item: Item in outside:
				item.draw.call()
	if painting == Painting.OUTSIDE:
		return
	# The garden and the weather are nearer than the railway, so a passing
	# train goes behind them; the hangar, drawn after, hides them but for the
	# door.
	_draw_garden()
	_draw_weather_outside()
	_draw_hangar_shell()
	_draw_end_wall()
	var items: Array[Item] = []
	items.append_array(_rib_items())
	items.append_array(_cradle_items())
	if not launched:
		items.append_array(_ship_items(built))
	items.sort_custom(func(a: Item, b: Item) -> bool: return a.depth > b.depth)
	for item: Item in items:
		item.draw.call()
	# The low sun's gold over everything.
	draw_rect(Rect2(0, 0, SIZE, SIZE), daylight.warm_tint())


## The clear sky's colour at a height on screen under `light`, as
## _draw_sky lays it (for bin/test's frame check, which gives the core's own
## daylight, so a hangar the window never fed fails it).
func clear_sky_at(light: Daylight, screen_y: float) -> Color:
	var horizon := SIZE * 0.5 + _focal * tan(_pitch)
	return light.top.lerp(light.bottom, clampf(screen_y / horizon, 0.0, 1.0))


func _sky_top() -> Color:
	return daylight.top.lerp(_shade(Color(0.62, 0.65, 0.70), daylight.ambient), conditions.cloud * 0.6)


func _sky_bottom() -> Color:
	return daylight.bottom.lerp(_shade(Color(0.62, 0.65, 0.70), daylight.ambient), conditions.cloud * 0.6)


func _draw_sky() -> void:
	var horizon := SIZE * 0.5 + _focal * tan(_pitch)
	var top := _sky_top()
	var bottom := _sky_bottom()
	_fan(PackedVector2Array([Vector2(0, 0), Vector2(SIZE, 0), Vector2(SIZE, horizon), Vector2(0, horizon)]),
		PackedColorArray([top, top, bottom, bottom]))
	var veil := 1.0 - 0.85 * conditions.cloud
	var shown := daylight.stars * (1.0 - conditions.cloud)
	if shown > 0.0:
		# The same stars every night: a fixed seed.
		var random := Random.new(7)
		for k in 120:
			var at := Vector2(random.unit() * SIZE, random.unit() * horizon * 0.85)
			_disc(at, 0.5 + random.unit() * 0.8, Color(1, 1, 0.95, shown * (0.4 + 0.6 * random.unit())))
	var light := _to_cam(_cam + _light * 100000.0)
	if light.z > 0.0:
		var at := _project(light)
		if daylight.sun_up:
			_disc(at, 58.0, Color(1, 1, 0.95, 0.10 * veil))
			_disc(at, 38.0, Color(1, 1, 0.95, 0.18 * veil))
			_disc(at, 21.0, Color(1.0, 0.98, 0.88, veil))
		elif daylight.moon_elevation > 0.0:
			_disc(at, 30.0, Color(0.85, 0.88, 1.0, 0.08 * veil))
			_disc(at, 13.0, Color(0.92, 0.93, 0.98, veil))


func _ridge_point(az_deg: float, dist: float, h: float) -> Vector3:
	var a := deg_to_rad(az_deg)
	return Vector3(sin(a) * dist, h, cos(a) * dist + DOOR_Z)


## The far range's peaks: azimuth, height, how far each flank runs to the
## left and to the right (degrees), so no two have the same shape.
const PEAKS := [
	[-62.0, 2916.0, 19.0, 23.0], [-47.0, 3276.0, 17.0, 19.0], [-34.0, 3564.0, 18.0, 15.0],
	[-25.0, 3204.0, 12.0, 14.0], [-14.0, 3924.0, 16.0, 12.0], [-6.0, 4500.0, 13.0, 15.0],
	[3.0, 3996.0, 11.0, 16.0], [14.0, 3420.0, 13.0, 15.0], [26.0, 3708.0, 16.0, 18.0],
	[39.0, 3276.0, 15.0, 17.0], [52.0, 3492.0, 17.0, 21.0], [66.0, 3060.0, 17.0, 21.0],
]


## A fixed roughness along the range: -1 to 1, the same every time, with no
## pattern the eye can follow.
func _crag(az: float, seed_: float) -> float:
	var a := az + seed_ * 37.0
	return (sin(a * 1.7 + 0.6 * sin(a * 0.43)) * 0.45 + sin(a * 4.1 + seed_ + 1.3 * sin(a * 0.9)) * 0.30
			+ sin(a * 9.7 + seed_ * 2.0) * 0.15 + sin(a * 21.3 + seed_ * 5.0) * 0.10)


## Height of the far range at an azimuth.
func _range_height(az: float) -> float:
	# One connected range: a high crest the peaks stand on, so the saddles
	# between them stay far above the foothills.
	var best := 2500.0 + 260.0 * _crag(az * 0.3, 9.0) + 110.0 * _crag(az * 1.1, 12.0)
	for k in PEAKS.size():
		var pk: Array = PEAKS[k]
		var off := az - float(pk[0])
		var flank: float = float(pk[2]) if off < 0.0 else float(pk[3])
		var t := 1.0 - absf(off) / flank
		if t <= 0.0:
			continue
		# Broad at the foot, steep near the top, with shoulders and notches.
		var h: float = float(pk[1]) * (0.62 * t + 0.38 * t * t)
		h += float(pk[1]) * (0.06 * _crag(az, float(k)) + 0.03 * _crag(az * 2.3, k + 20.0)) * minf(1.0, t * 3.0 + 0.2)
		best = maxf(best, h)
	return best


## How high the ground stands: level in the valley, where the railway runs,
## then rising to the crest of the near hills.
func _ground(az: float, dist: float) -> float:
	var k := smoothstep(HILLS_FOOT, HILLS_CREST, dist)
	return k * (170.0 + 60.0 * sin(az * 0.08 + 0.77) + 26.0 * sin(az * 0.31 + 2.31) + 8.0 * _crag(az * 0.5, 3.0))


func _ground_point(az: float, dist: float) -> Vector3:
	return _ridge_point(az, dist, _ground(az, dist))


## The ground under a spot in the world.
func _ground_at(x: float, z: float) -> float:
	var t := z - DOOR_Z
	return _ground(rad_to_deg(atan2(x, t)), Vector2(x, t).length())


func _draw_land() -> void:
	var horizon := SIZE * 0.5 + _focal * tan(_pitch)
	var dim := 0.3 + 0.7 * _day
	var far_grass := _shade(Color(0.46, 0.58, 0.40), dim)
	var near_grass := _shade(Color(0.36, 0.50, 0.28), dim)
	_fan(PackedVector2Array([Vector2(0, horizon - 2), Vector2(SIZE, horizon - 2), Vector2(SIZE, SIZE), Vector2(0, SIZE)]),
		PackedColorArray([far_grass, far_grass, near_grass, near_grass]))
	# The far range: grey-blue peaks, sunlit where they face left, snow on top.
	var dist := 14000.0
	var step := 0.25
	var count := int(150.0 / step)
	# Each height once: the slices share their corners.
	var heights := PackedFloat32Array()
	for k in count + 1:
		heights.append(_range_height(-75.0 + k * step))
	var foot := _sky_bottom()
	for k in count:
		var az := -75.0 + k * step
		var h0 := heights[k]
		var h1 := heights[k + 1]
		# A face that climbs to the right looks left, into the light.
		var lit := heights[mini(k + 4, count)] > heights[maxi(k - 4, 0)]
		var face := _shade(Color(0.68, 0.72, 0.80) if lit else Color(0.50, 0.55, 0.66), dim)
		_poly([_ridge_point(az, dist, h0), _ridge_point(az + step, dist, h1),
				_ridge_point(az + step, dist, -60), _ridge_point(az, dist, -60)],
			[face, face, foot, foot])
		var snow0 := _snow_depth(az, h0)
		var snow1 := _snow_depth(az + step, h1)
		if snow0 > 0.0 or snow1 > 0.0:
			var white := _shade(Color(0.96, 0.97, 0.99) if lit else Color(0.80, 0.85, 0.92), dim)
			_flat([_ridge_point(az, dist, h0), _ridge_point(az + step, dist, h1),
					_ridge_point(az + step, dist, h1 - snow1), _ridge_point(az, dist, h0 - snow0)],
				white)
	# Foothills, each row higher and hazier than the one in front.
	_draw_hills(9000.0, 900.0, 260.0, _shade(Color(0.42, 0.52, 0.56), dim), _shade(Color(0.58, 0.66, 0.70), dim), 0.31)
	_draw_hills(5200.0, 430.0, 150.0, _shade(Color(0.34, 0.47, 0.42), dim), _shade(Color(0.48, 0.58, 0.54), dim), 1.9)
	_draw_ground(far_grass, near_grass)
	_draw_railway(dim)
	_draw_road(dim)


func _snow_depth(az: float, h: float) -> float:
	var over := h - 2900.0
	if over <= 0.0:
		return 0.0
	# Ragged lower edge: streaks of snow running down the gullies.
	var streak := maxf(0.0, _crag(az * 1.3, 4.0)) * 380.0 + maxf(0.0, sin(az * 23.0 + 1.0)) * 120.0
	return over * 0.4 + streak * 1.6 * clampf(over / 800.0, 0.0, 1.0)


func _draw_hills(dist: float, base_h: float, swing: float, top: Color, foot: Color, seed_: float) -> void:
	var az := -75.0
	var step := 1.0
	while az < 75.0:
		var a2 := az + step
		_poly([_ridge_point(az, dist, _hill(az, base_h, swing, seed_)), _ridge_point(a2, dist, _hill(a2, base_h, swing, seed_)),
				_ridge_point(a2, dist, -40), _ridge_point(az, dist, -40)],
			[top, top, foot, foot])
		az = a2


func _hill(az: float, base_h: float, swing: float, seed_: float) -> float:
	return (base_h + swing * sin(az * 0.08 + seed_) + swing * 0.4 * sin(az * 0.31 + seed_ * 3.0)
			+ swing * 0.25 * _crag(az * 0.4, seed_))


## The near hills: the valley floor climbing to their crest, as real ground
## (the road runs up it), far rows first.
func _draw_ground(far_grass: Color, near_grass: Color) -> void:
	var rows := 16
	var cols := 50
	# The valley floor behind is nearly the far grass where the hills begin,
	# so they start in it: no step along their foot.
	var foot := far_grass.lerp(near_grass, 0.06)
	var crest := far_grass.lerp(near_grass, 0.45)
	# Each corner once: a row of points and lights at each distance.
	var points: Array[Vector3] = []
	var colours: Array[Color] = []
	for row in rows + 1:
		var d := lerpf(HILLS_FOOT, HILLS_CREST, float(row) / rows)
		var colour := foot.lerp(crest, sin(PI * 0.5 * float(row) / rows))
		for col in cols + 1:
			var az := -75.0 + col * 150.0 / cols
			points.append(_ground_point(az, d))
			colours.append(_shade(colour, _slope_light(az, d)))
	for row in range(rows, 0, -1):
		for col in cols:
			var a := row * (cols + 1) + col
			var b := (row - 1) * (cols + 1) + col
			_poly([points[a], points[a + 1], points[b + 1], points[b]],
				[colours[a], colours[a + 1], colours[b + 1], colours[b]])


func _slope_light(az: float, dist: float) -> float:
	return 1.0 + 0.10 * clampf((_ground(az + 1.5, dist) - _ground(az - 1.5, dist)) / 14.0, -1.0, 1.0)


## The railway across the valley: a ballast bank with its rails, and a
## level crossing where the road meets it, a white post each side.
func _draw_railway(dim: float) -> void:
	var z := RAILWAY_Z
	_flat([Vector3(-4000, 0.6, z - 7), Vector3(4000, 0.6, z - 7), Vector3(4000, 0.6, z + 7), Vector3(-4000, 0.6, z + 7)],
		_shade(Color(0.45, 0.40, 0.34), dim))
	for side: float in [-2.4, 2.4]:
		_beam(Vector3(-4000, 1.2, z + side), Vector3(4000, 1.2, z + side), 0.5, _shade(Color(0.25, 0.24, 0.24), dim), Color(0, 0, 0, 0))
	var crossing := _road_x(z)
	# Beyond the track, so a passing train goes in front of them.
	for side: float in [-14.0, 14.0]:
		var foot := Vector3(crossing + side, 0, z + 12)
		_beam(foot, foot + Vector3(0, 10, 0), 0.8, _shade(Color(0.92, 0.92, 0.9), dim), Color(0, 0, 0, 0))


## Where the railway meets the road, across the valley.
func crossing_x() -> float:
	return _road_x(RAILWAY_Z)


func _road_x(z: float) -> float:
	var t := z - DOOR_Z
	return 260.0 * t / HILLS_CREST + 70.0 * sin(t / 420.0)


## The road: one ribbon from the door, over the crossing and up the hill to
## its crest, narrowing with distance as the ground carries it.
func _draw_road(dim: float) -> void:
	var colour := _shade(Color(0.66, 0.58, 0.44), dim)
	# Projected unclipped: the road starts at the door, far in front of the
	# camera, and stops short of the crest, where it goes over out of sight.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var z := DOOR_Z
	while z <= DOOR_Z + 0.9 * HILLS_CREST:
		var x := _road_x(z)
		var y := _ground_at(x, z) + 0.2
		left.append(_project(_to_cam(Vector3(x - 9.0, y, z))))
		right.append(_project(_to_cam(Vector3(x + 9.0, y, z))))
		z += 15.0
	for k in left.size() - 1:
		_fan(PackedVector2Array([left[k], left[k + 1], right[k + 1], right[k]]),
			PackedColorArray([colour, colour, colour, colour]))


# ---------------------------------------------------------------- the garden

func _draw_garden() -> void:
	var soil := Color(0.30, 0.22, 0.15)
	_flat([Vector3(-118, 0.3, DOOR_Z + 24), Vector3(-118, 0.3, DOOR_Z + 76),
			Vector3(-22, 0.3, DOOR_Z + 76), Vector3(-22, 0.3, DOOR_Z + 24)], soil)
	# Eight places, each plant in the next one round: once the plot is full
	# a new plant takes the oldest one's place, and the rest stay put.
	var places := 8
	var standing: Array[int] = []
	standing.resize(places)
	standing.fill(-1)
	for k in garden_plants.size():
		standing[k % places] = garden_plants[k]
	# Far row first, so the near row stands in front.
	for place: int in [4, 5, 6, 7, 0, 1, 2, 3]:
		if standing[place] >= 0:
			# The far row stands in the gaps of the near one.
			var far := place >= 4
			_draw_plant(Vector3(-110.0 + (place % 4) * 24.0 + (12.0 if far else 0.0), 0, DOOR_Z + (64.0 if far else 34.0)), standing[place])


func _draw_plant(base: Vector3, kind: int) -> void:
	var stem_top := base + Vector3(0, 15, 0)
	var stem := Color(0.55, 0.40, 0.18)
	_beam(base, stem_top, 0.8, stem, Color(0, 0, 0, 0))
	var c := _to_cam(stem_top)
	if c.z < NEAR:
		return
	var at := _project(c)
	var px := _focal / c.z
	match kind:
		0:  # gear-flower
			_gear(at, 6.0 * px, 10, BRASS)
			_disc(at, 2.0 * px, Color(0.45, 0.30, 0.12))
		1:  # pipe-vine: copper tubes curling up
			for k in 3:
				var off := Vector2((k - 1) * 2.4, 0) * px
				_beam(base + Vector3((k - 1) * 2.0, 0, 0), stem_top + Vector3((k - 1) * 3.0, 2.0 - absf(k - 1) * 3.0, 0),
					0.9, COPPER, Color(1, 0.8, 0.6, 0.5))
				_disc(at + off + Vector2(0, -(2.0 - absf(k - 1) * 3.0) * px), 0.9 * px, Color(0.55, 0.30, 0.18))
		2:  # girder-reed: light metal lattice stalks
			for k in 3:
				var top := base + Vector3((k - 1) * 3.0, 20.0 - absf(k - 1) * 5.0, 0)
				_girder(base + Vector3((k - 1) * 1.2, 0, 0), top, 1.6, ALLOY, Color(1, 1, 1, 0.5))
				var tc := _to_cam(top)
				if tc.z > NEAR:
					_disc(_project(tc), 1.0 * _focal / tc.z, BRASS)
		3:  # sail-cotton: bolls of cloth for the envelope
			for k in 5:
				var ang := deg_to_rad(-160.0 + k * 35.0)
				var tip := at + Vector2(cos(ang), sin(ang)) * 6.0 * px
				_strip(at, tip, 0.35 * px, 0.25 * px, Color(0.55, 0.40, 0.18))
				_disc(tip, 2.4 * px, CANVAS.darkened(0.12))
				_disc(tip + Vector2(-0.5, -0.6) * px, 1.7 * px, CANVAS.lightened(0.1))
		_:  # kettle-gourd: ripens into a boiler drum
			var body := at + Vector2(0, 3.0 * px)
			_disc(body, 5.5 * px, COPPER.darkened(0.15))
			_disc(body + Vector2(-1.4, -1.6) * px, 3.2 * px, COPPER.lightened(0.15))
			_strip(body + Vector2(0, -5.5) * px, body + Vector2(0, -8.0) * px, 0.8 * px, 0.6 * px, BRASS.darkened(0.2))


func _gear(centre: Vector2, radius: float, teeth: int, colour: Color) -> void:
	var pts := PackedVector2Array([centre])
	var cols := PackedColorArray([colour.lightened(0.25)])
	var n := teeth * 4
	for k in n + 1:
		var ang := TAU * k / n
		var r := radius if (k % 4) < 2 else radius * 0.78
		pts.append(centre + Vector2(cos(ang), sin(ang)) * r)
		cols.append(colour.darkened(0.15))
	_fan(pts, cols)


# ---------------------------------------------------------------- the hangar

## A point on the hangar's arch: t runs 0 (left floor) to 1 (right floor);
## inset moves it in from the outer skin.
func _arch(t: float, inset: float) -> Vector2:
	var ang := PI * (1.0 - t)
	var x := HALF_W * cos(ang)
	var y := HANGAR_H * pow(maxf(sin(ang), 0.0), 0.62)
	return Vector2(x * (HALF_W - inset) / HALF_W, y * (HANGAR_H - inset) / HANGAR_H)


## How lit the hangar is at a depth: brightest by the door, by day; at night
## the lanterns keep it from going black.
func _interior_light(z: float) -> float:
	var t := clampf(z / DOOR_Z, 0.0, 1.0)
	return (0.4 + 0.75 * t * t * t) * (0.38 + 0.62 * _day)


## Clouds in the doorway's patch of sky, as Grove drew them: each a heap of
## soft puffs, of three kinds (heaped, layered, wispy), lit by the hour and
## tinted by the sky. More of them show as the cover grows. Drawn still;
## their places fixed.
func _draw_clouds() -> void:
	if conditions.cloud <= 0.02:
		return
	var level := (0.24 + 0.73 * daylight.ambient) * (1.0 - 0.4 * conditions.rain)
	var sky := _sky_top().lerp(_sky_bottom(), 0.6)
	var mean := (sky.r + sky.g + sky.b) / 3.0
	var cast := clampf(0.8 * (1.0 - daylight.ambient) / 0.78, 0.0, 0.6)
	var tone := Color(clampf(level * 0.98 + cast * (sky.r - mean), 0.0, 1.0),
		clampf(level * 0.99 + cast * (sky.g - mean), 0.0, 1.0),
		clampf(level + cast * (sky.b - mean), 0.0, 1.0))
	var shade := Color(tone.r * 0.66, tone.g * 0.71, tone.b * 0.8)
	for k in 9:
		var shown := clampf(conditions.cloud * 9.0 - k, 0.0, 1.0) * (0.7 + 0.3 * conditions.cloud)
		if shown <= 0.0:
			continue
		var a := absf(sin(k * 91.7 + 1.3))
		var b := absf(sin(k * 47.1 + 2.9))
		var w := 120.0 + 100.0 * a
		var corner := Vector2(70.0 + fposmod(a * 7.0 + k * 0.37, 1.0) * 480.0 - w * 0.5, 226.0 + 62.0 * b)
		_draw_cloud(k + 1, Rect2(corner, Vector2(w, w * 0.44)), tone, shade, shown)


func _draw_cloud(seed_: int, box: Rect2, tone: Color, shade: Color, shown: float) -> void:
	var r := Random.new(seed_ * 7919 + 13)
	var w := box.size.x
	var h := box.size.y
	var puff := func(x: float, y: float, rad: float, stretch: float, colour: Color, alpha: float) -> void:
		# Kept inside the cloud's box, as Grove did: flat bases, no stray wisps.
		var inside := maxf(1.0, minf(minf(rad, y), minf(h - y, minf(x, w - x))))
		var wide := maxf(1.0, minf(stretch, minf(x / inside, (w - x) / inside)))
		_puff(box.position + Vector2(x, y), inside, wide, colour, alpha * shown)
	match seed_ % 3:
		0:  # heaped: a flat base, rounded towers, frayed ends
			var bottom := h * 0.8
			var n := 10 + int(r.unit() * 6)
			for i in n:
				var t := (i + 0.5) / n
				var rad := h * (0.15 + 0.3 * sin(PI * t) * (0.5 + 0.5 * r.unit()))
				var x := w * (0.1 + 0.8 * t) + (r.unit() - 0.5) * w * 0.05
				puff.call(x, bottom - rad * (0.5 + 0.35 * r.unit()), rad * 1.3, 1.0 + r.unit() * 0.3, tone, 0.62)
			for m in 3 + int(r.unit() * 4):
				puff.call(w * (0.22 + 0.56 * r.unit()), bottom - h * (0.3 + 0.25 * r.unit()),
					h * (0.12 + 0.14 * r.unit()), 1.0 + r.unit() * 0.3, tone, 0.55)
			puff.call(w * 0.5, bottom - h * 0.02, h * 0.2, w / (h * 0.2) * 0.42, shade, 0.4)
			for q in 5 + int(r.unit() * 4):
				var left := r.unit() < 0.5
				puff.call(w * (0.22 * r.unit() if left else 0.78 + 0.22 * r.unit()), bottom - h * (0.02 + 0.22 * r.unit()),
					h * (0.08 + 0.1 * r.unit()), 3.0 + r.unit() * 5.0, tone, 0.3)
		1:  # layered: a long low bank
			var count := 8 + int(r.unit() * 5)
			for i in count:
				var t := (i + 0.5) / count
				puff.call(w * (0.08 + 0.84 * t) + (r.unit() - 0.5) * w * 0.05, h * (0.5 + (r.unit() - 0.5) * 0.14),
					h * (0.12 + 0.14 * r.unit()), 2.5 + r.unit() * 3.0, tone, 0.45)
			puff.call(w * 0.5, h * 0.64, h * 0.16, w / (h * 0.16) * 0.4, shade, 0.28)
			for q in 7 + int(r.unit() * 4):
				puff.call(w * (0.02 + 0.96 * r.unit()), h * (0.3 + 0.5 * r.unit()), h * (0.06 + 0.07 * r.unit()),
					5.0 + r.unit() * 5.0, tone, 0.24)
		_:  # wispy: thin curved strokes
			for c in 6 + int(r.unit() * 5):
				var x0 := w * (0.05 + 0.55 * r.unit())
				var y0 := h * (0.2 + 0.6 * r.unit())
				var bend := (r.unit() - 0.5) * 0.5
				for j in 3 + int(r.unit() * 3):
					puff.call(x0 + j * w * 0.09, y0 + j * j * h * 0.03 * bend, h * (0.06 + 0.05 * r.unit()),
						4.0 + r.unit() * 4.0, tone, 0.26)


## A soft round puff, `stretch` times as wide as tall: solid at the heart,
## fading to nothing at its edge.
func _puff(centre: Vector2, rad: float, stretch: float, colour: Color, alpha: float) -> void:
	var steps := 20
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([Color(colour, alpha)])
	for ring: Array in [[0.5, 0.45], [1.0, 0.0]]:
		for k in steps:
			var angle := TAU * k / steps
			points.append(centre + Vector2(cos(angle) * rad * stretch, sin(angle) * rad) * float(ring[0]))
			colours.append(Color(colour, alpha * float(ring[1])))
	var idx := PackedInt32Array()
	for k in steps:
		var n := (k + 1) % steps
		idx.append_array([0, 1 + k, 1 + n])
		idx.append_array([1 + k, 1 + steps + k, 1 + steps + n])
		idx.append_array([1 + k, 1 + steps + n, 1 + n])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, points, colours)


## Rain, snow and fog, all outside, in front of the land, the railway and
## the garden, and behind the hangar, so they show only through the door.
## Drawn still; their places are fixed.
func _draw_weather_outside() -> void:
	var lit := 0.15 + 0.85 * _day
	var horizon := SIZE * 0.5 + _focal * tan(_pitch)
	if conditions.rain > 0.0 and not moving_weather:
		var random := Random.new(13)
		for k in 220:
			var top := Vector2(random.unit() * SIZE, random.unit() * SIZE * 0.75)
			draw_line(top, top + Vector2(-4, 16), Color(0.75, 0.82, 0.92, 0.5 * conditions.rain), 1.0, true)
	if conditions.fog > 0.0:
		# Over the sky, the peaks and the garden alike, thickest low down.
		var veil := Color(0.86 * lit + 0.05, 0.88 * lit + 0.05, 0.9 * lit + 0.05, 0.55 * conditions.fog)
		var thick := Color(veil, 0.95 * conditions.fog)
		_fan(PackedVector2Array([Vector2(0, 200), Vector2(SIZE, 200), Vector2(SIZE, horizon + 40), Vector2(0, horizon + 40)]),
			PackedColorArray([veil, veil, thick, thick]))
		_fan(PackedVector2Array([Vector2(0, horizon + 40), Vector2(SIZE, horizon + 40), Vector2(SIZE, SIZE), Vector2(0, SIZE)]),
			_same(thick, 4))
	if conditions.snow > 0.0 and not moving_weather:
		var random := Random.new(17)
		for k in 240:
			_disc(Vector2(random.unit() * SIZE, random.unit() * SIZE * 0.75), 0.9 + random.unit() * 1.4,
				Color(1, 1, 1, 0.85 * conditions.snow))


func _draw_hangar_shell() -> void:
	var back := _cam.z - 60.0
	# Roof and walls: planks running from the back to the doors.
	for k in ARCH_STEPS:
		var t0 := float(k) / ARCH_STEPS
		var t1 := float(k + 1) / ARCH_STEPS
		var a := _arch(t0, 0.0)
		var b := _arch(t1, 0.0)
		var height := (a.y + b.y) * 0.5 / HANGAR_H
		var tone := 1.0 - height * 0.35 + (0.06 if k % 2 == 0 else 0.0)
		var far := _shade(WOOD, tone * _interior_light(DOOR_Z))
		var near := _shade(WOOD_DARK, tone * 0.8)
		_poly([Vector3(a.x, a.y, back), Vector3(a.x, a.y, DOOR_Z), Vector3(b.x, b.y, DOOR_Z), Vector3(b.x, b.y, back)],
			[near, far, far, near])
	for k in ARCH_STEPS + 1:
		var p := _arch(float(k) / ARCH_STEPS, 0.0)
		_beam(Vector3(p.x, p.y, back), Vector3(p.x, p.y, DOOR_Z), 0.5, Color(0.08, 0.05, 0.03, 0.6), Color(0, 0, 0, 0))
	# Floor: long boards, brighter towards the open doors.
	var floor_far := _shade(CONCRETE, _interior_light(DOOR_Z) * 1.1)
	var floor_near := _shade(CONCRETE, 0.35)
	_poly([Vector3(-HALF_W, 0, back), Vector3(-HALF_W, 0, DOOR_Z), Vector3(HALF_W, 0, DOOR_Z), Vector3(HALF_W, 0, back)],
		[floor_near, floor_far, floor_far, floor_near])
	var seam := Color(0.08, 0.05, 0.03, 0.45)
	var x := -HALF_W + 7.5
	var row := 0
	while x < HALF_W:
		_beam(Vector3(x, 0.05, back), Vector3(x, 0.05, DOOR_Z), 0.35, seam, Color(0, 0, 0, 0))
		# Board ends, staggered row by row.
		var z := -20.0 + (row % 3) * 23.0
		while z < DOOR_Z:
			_beam(Vector3(x, 0.05, z), Vector3(x + 7.5, 0.05, z), 0.35, seam, Color(0, 0, 0, 0))
			z += 70.0
		x += 7.5
		row += 1
	_draw_sun_patch()


## The door's rectangle thrown along the floor by the low sun.
func _draw_sun_patch() -> void:
	if _sun <= 0.02:
		return
	var to_floor := -_light
	var reach := DOOR_H / -to_floor.y
	var warm := Color(1.0, 0.84, 0.58, 0.42 * _sun)
	var faint := Color(1.0, 0.84, 0.58, 0.05 * _sun)
	var corners: Array[Vector3] = []
	for x: float in [DOOR_HALF_W, -DOOR_HALF_W]:
		var hit := Vector3(x, DOOR_H, DOOR_Z) + to_floor * reach
		corners.append(Vector3(clampf(hit.x, -HALF_W, HALF_W), 0.1, maxf(hit.z, _cam.z - 50.0)))
	_poly([Vector3(-DOOR_HALF_W, 0.1, DOOR_Z), Vector3(DOOR_HALF_W, 0.1, DOOR_Z), corners[0], corners[1]],
		[warm, warm, faint, faint])


## Height of the arch at a distance across the hangar.
func _arch_height(x: float) -> float:
	var ang := acos(clampf(x / HALF_W, -1.0, 1.0))
	return HANGAR_H * pow(maxf(sin(ang), 0.0), 0.62)


## The end wall: upright boards, dark against the daylight, round one huge
## rectangular door.
func _draw_end_wall() -> void:
	var z := DOOR_Z
	var step := 6.0
	var x := -HALF_W
	var k := 0
	while x < HALF_W - 0.01:
		var x2 := minf(x + step, HALF_W)
		var mid := (x + x2) * 0.5
		var bottom := 0.0 if absf(mid) > DOOR_HALF_W else DOOR_H
		var tone := 0.55 if k % 2 == 0 else 0.62
		var top_col := _shade(WOOD, tone * 0.7)
		var low_col := _shade(WOOD, tone)
		_poly([Vector3(x, bottom, z), Vector3(x, _arch_height(x), z), Vector3(x2, _arch_height(x2), z), Vector3(x2, bottom, z)],
			[low_col, top_col, top_col, low_col])
		x = x2
		k += 1
	# Cross-bracing on the wall, and a heavy timber frame round the door.
	var beam := _shade(WOOD, 0.5)
	var shine := Color(1.0, 0.85, 0.6, 0.25)
	for y: float in [DOOR_H + 18.0, DOOR_H + 36.0]:
		var half := HALF_W * cos(asin(clampf(y / HANGAR_H, 0.0, 1.0))) * 0.98
		_beam(Vector3(-half, y, z - 1), Vector3(half, y, z - 1), 3.0, beam, shine)
	for side: float in [-1.0, 1.0]:
		var x0 := side * DOOR_HALF_W
		_beam(Vector3(x0, 0, z - 2), Vector3(x0, DOOR_H, z - 2), 7.0, beam, shine)
		_beam(Vector3(side * (DOOR_HALF_W + 11), 0, z - 1), Vector3(side * (HALF_W - 4), 95, z - 1), 2.5, beam, shine)
	_beam(Vector3(-DOOR_HALF_W - 3, DOOR_H, z - 2), Vector3(DOOR_HALF_W + 3, DOOR_H, z - 2), 8.0, beam, shine)
	# Daylight catching the edge of the opening.
	var edge := Color(1.0, 0.92, 0.75, 0.5)
	_beam(Vector3(-DOOR_HALF_W + 3.5, 0, z - 3), Vector3(-DOOR_HALF_W + 3.5, DOOR_H - 4, z - 3), 1.0, edge, Color(0, 0, 0, 0))
	_beam(Vector3(-DOOR_HALF_W + 4, DOOR_H - 4, z - 3), Vector3(DOOR_HALF_W - 4, DOOR_H - 4, z - 3), 1.0, edge, Color(0, 0, 0, 0))


func _rib_items() -> Array[Item]:
	var items: Array[Item] = []
	var z := DOOR_Z - RIB_STEP
	while z > _cam.z + 8.0:
		var rz := z
		items.append(Item.new(_depth(Vector3(0, HANGAR_H * 0.5, rz)), func() -> void: _draw_rib(rz)))
		z -= RIB_STEP
	return items


## One laminated timber arch: an outer and an inner chord, with lattice
## between, lanterns hung from it.
func _draw_rib(z: float) -> void:
	var depth := 16.0 if z < DOOR_Z else 22.0
	var lit := _interior_light(z)
	var chord := _shade(WOOD, lit * 1.05)
	var chord_dark := _shade(WOOD, lit * 0.7)
	var shine := Color(1.0, 0.85, 0.6, 0.18 * lit)
	for k in ARCH_STEPS:
		var t0 := float(k) / ARCH_STEPS
		var t1 := float(k + 1) / ARCH_STEPS
		for band: Vector2 in [Vector2(0.0, 3.5), Vector2(depth - 3.5, depth)]:
			var a0 := _arch(t0, band.x)
			var a1 := _arch(t1, band.x)
			var b0 := _arch(t0, band.y)
			var b1 := _arch(t1, band.y)
			_poly([Vector3(a0.x, a0.y, z), Vector3(a1.x, a1.y, z), Vector3(b1.x, b1.y, z), Vector3(b0.x, b0.y, z)],
				[chord_dark, chord_dark, chord, chord])
		var p := _arch(t0 if k % 2 == 0 else t1, 3.0)
		var q := _arch(t1 if k % 2 == 0 else t0, depth - 3.0)
		_beam(Vector3(p.x, p.y, z), Vector3(q.x, q.y, z), 1.6, chord_dark, shine)
	if z < DOOR_Z and roundi((DOOR_Z - z) / RIB_STEP) % 2 == 1:
		# Along the walls, clear of the airship's hull.
		for t: float in [0.25, 0.86]:
			var hang := _arch(t, depth)
			var top := Vector3(hang.x, hang.y, z)
			var lamp := top + Vector3(0, -30, 0)
			_beam(top, lamp, 0.25, Color(0.1, 0.08, 0.06), Color(0, 0, 0, 0))
			var c := _to_cam(lamp)
			if c.z > NEAR:
				var at := _project(c)
				var s := _focal / c.z
				# Lanterns count for more as the day goes.
				_glow(at, (26.0 + 6.0 * (1.0 - _day)) * s, Color(1.0, 0.75, 0.40, 0.3 + 0.15 * (1.0 - _day)))
				_disc(at, 1.6 * s, Color(1.0, 0.88, 0.6))


func _cradle_items() -> Array[Item]:
	var items: Array[Item] = []
	for zl: float in [-90.0, 0.0, 90.0]:
		var z := SHIP_ORIGIN.z + zl * SHIP_SCALE
		var top_y := SHIP_ORIGIN.y - _radius((zl + SHIP_L * 0.5) / SHIP_L) * SHIP_SCALE * 0.92
		items.append(Item.new(_depth(Vector3(0, 20, z)) + 30.0, func() -> void: _draw_cradle(z, top_y)))
	return items


func _draw_cradle(z: float, top_y: float) -> void:
	var lit := _interior_light(z)
	var c := _shade(WOOD, lit * 0.9)
	var shine := Color(1.0, 0.85, 0.6, 0.15)
	var x := SHIP_ORIGIN.x
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(x + side * 48, 0, z), Vector3(x + side * 22, top_y, z), 4.5, c, shine)
		_beam(Vector3(x + side * 48, 0, z - 9), Vector3(x + side * 48, 0, z + 9), 6.0, _shade(c, 0.7), Color(0, 0, 0, 0))
	_beam(Vector3(x - 40, top_y * 0.4, z), Vector3(x + 40, top_y * 0.4, z), 3.5, c, shine)
	_beam(Vector3(x - 26, top_y, z), Vector3(x + 26, top_y, z), 4.5, c, shine)


# --------------------------------------------------------------- the airship

## Hull radius at s (0 tail, 1 nose): a blunt nose and a long taper aft.
func _radius(s: float) -> float:
	var c := 0.62
	if s >= c:
		var u := (s - c) / (1.0 - c)
		return SHIP_R * sqrt(maxf(0.0, 1.0 - u * u))
	var v := (c - s) / c
	return SHIP_R * pow(maxf(0.0, 1.0 - v * v), 0.8)


func _station_s(i: int) -> float:
	return float(i) / STATIONS


func _hull_local(i: int, j: int, swell: float) -> Vector3:
	var s := _station_s(i)
	var r := _radius(s) * swell
	var phi := TAU * j / LONGERONS
	return Vector3(r * sin(phi), -r * cos(phi), (s - 0.5) * SHIP_L)


func _hull_normal(i: int, j: int) -> Vector3:
	var s := _station_s(i)
	var ds := 0.01
	var slope := (_radius(minf(s + ds, 1.0)) - _radius(maxf(s - ds, 0.0))) / (2.0 * ds * SHIP_L)
	var phi := TAU * j / LONGERONS
	return Vector3(sin(phi), -cos(phi), -slope).normalized()


func _world(local: Vector3) -> Vector3:
	return _ship_origin + _ship_basis * (local * SHIP_SCALE)


## Lit metal: a dim hangar, the low sun through the doors, a sharp highlight.
func _metal(base: Color, world_p: Vector3, world_n: Vector3) -> Color:
	var diffuse := maxf(world_n.dot(_light), 0.0) * (_sun + _moon)
	var view := (_cam - world_p).normalized()
	var half := (view + _light).normalized()
	var spec := pow(maxf(world_n.dot(half), 0.0), 18.0) * (_sun + _moon)
	var ambient := (0.62 if not launched else 0.85) * (0.35 + 0.65 * _day)
	var sky := maxf(world_n.y, 0.0) * 0.15 * _day
	var f := ambient + sky + diffuse * 0.75
	return Color(base.r * f + spec * 0.9, base.g * f + spec * 0.8, base.b * f + spec * 0.55)


## Stations taken in turn from the front third (nose first), the middle and
## the tail, so the front third, the part in view, gains a share of every
## stage while it happens.
func _spread() -> Array[int]:
	var third := STATIONS / 3.0
	var sections: Array = [[], [], []]
	for i in range(STATIONS - 1, -1, -1):
		var section := 0 if i >= STATIONS - third else (1 if i >= third else 2)
		(sections[section] as Array).append(i)
	var order: Array[int] = []
	var k := 0
	while order.size() < STATIONS:
		for sec: Array in sections:
			if k < sec.size():
				order.append(sec[k] as int)
		k += 1
	return order


func _plan_build() -> void:
	_parts.clear()
	var order := _spread()
	for i: int in order:
		_parts.append(Part.new(KEEL, i, 0, 0.4))
	for i: int in order:
		if i > 0:
			_parts.append(Part.new(RING, i, 0, 1.6))
	# The fins sit out of view at the tail: small, so they go in early.
	for k in 4:
		_parts.append(Part.new(FIN, k, 0, 1.8))
	# Longerons climb the sides in pairs.
	var half := LONGERONS >> 1
	for d in range(1, half + 1):
		for j: int in [d, LONGERONS - d]:
			if j == half and d != half:
				continue
			for i: int in order:
				_parts.append(Part.new(LONGERON, i, j, 0.075))
			if d == half:
				break
	# The gondola with its boiler, then the two steam engines.
	_parts.append(Part.new(GONDOLA, 0, 0, 7.0))
	for k in 2:
		_parts.append(Part.new(ENGINE, k, 0, 2.5))
	# Cloth goes on in rows, alternately from the keel up and the crown down,
	# each row spread along the ship, so the last open band runs along the
	# sides, at eye level.
	var rows: Array[int] = []
	for d in range(0, LONGERONS >> 2):
		rows.append_array([LONGERONS - 1 - d, d, half - 1 - d, half + d])
	for j: int in rows:
		for i: int in order:
			_parts.append(Part.new(CLOTH, i, j, 0.052))
	_total_cost = 0.0
	for p: Part in _parts:
		_total_cost += p.cost


func _ship_items(amount: float) -> Array[Item]:
	var budget := amount * _total_cost
	var keel := {}
	var rings := {}
	var longerons := {}
	var cloth := {}
	var fins := 0
	var gondola := false
	var engines := 0
	for p: Part in _parts:
		if budget < p.cost * 0.5:
			break
		budget -= p.cost
		match p.kind:
			KEEL: keel[p.i] = true
			RING: rings[p.i] = true
			LONGERON: longerons[Vector2i(p.i, p.j)] = true
			CLOTH: cloth[Vector2i(p.i, p.j)] = true
			FIN: fins += 1
			GONDOLA: gondola = true
			ENGINE: engines += 1
	var items: Array[Item] = []
	# Girders, left out where cloth covers them on both sides.
	for i: int in keel:
		if not (cloth.has(Vector2i(i, 0)) and cloth.has(Vector2i(i, LONGERONS - 1))):
			items.append(_member_item(i, 0, i + 1, 0, 3.0))
	for key: Vector2i in longerons:
		var jm := (key.y + LONGERONS - 1) % LONGERONS
		if not (cloth.has(key) and cloth.has(Vector2i(key.x, jm))):
			items.append(_member_item(key.x, key.y, key.x + 1, key.y, 1.4))
	for i: int in rings:
		for j in LONGERONS:
			var jn := (j + 1) % LONGERONS
			if not (cloth.has(Vector2i(i, j)) and cloth.has(Vector2i(i - 1, j))):
				items.append(_member_item(i, j, i, jn, 2.4))
	for key: Vector2i in cloth:
		items.append(_cloth_item(key.x, key.y))
	if gondola:
		items.append_array(_gondola_items(engines))
	for k in fins:
		items.append(_fin_item(k))
	if launched:
		items.append_array(_exhaust_items(engines))
	return items


## Light metal girder: two rails with a zigzag web between them, or a plain
## bar when it is too small on screen for the web to show.
func _girder(a: Vector3, b: Vector3, width: float, colour: Color, shine: Color) -> void:
	var ca := _to_cam(a)
	var cb := _to_cam(b)
	if ca.z < NEAR and cb.z < NEAR:
		return
	if ca.z < NEAR:
		ca = cb.lerp(ca, (cb.z - NEAR) / (cb.z - ca.z))
	elif cb.z < NEAR:
		cb = ca.lerp(cb, (ca.z - NEAR) / (ca.z - cb.z))
	var wa := _focal * width / ca.z * 0.5
	var wb := _focal * width / cb.z * 0.5
	if maxf(wa, wb) < 2.5:
		_beam(a, b, width * 0.5, colour, shine)
		return
	var pa := _project(ca)
	var pb := _project(cb)
	var along := pb - pa
	if along.length() < 0.01:
		return
	var side := Vector2(-along.y, along.x).normalized()
	var rail := 0.2
	for s: float in [-1.0, 1.0]:
		var c := colour if s > 0.0 else _shade(colour, 0.8)
		var a0 := pa + side * s * wa * (1.0 - rail)
		var b0 := pb + side * s * wb * (1.0 - rail)
		_strip(a0, b0, wa * rail, wb * rail, c)
		if s > 0.0 and shine.a > 0.0:
			_strip(a0 + side * wa * rail * 0.4, b0 + side * wb * rail * 0.4, wa * rail * 0.35, wb * rail * 0.35, shine)
	var bays := maxi(2, int(along.length() / maxf(wa + wb, 1.0)))
	var web := _shade(colour, 0.85)
	for k in bays:
		var t0 := float(k) / bays
		var t1 := float(k + 1) / bays
		var s0 := 1.0 if k % 2 == 0 else -1.0
		var w0 := lerpf(wa, wb, t0)
		var w1 := lerpf(wa, wb, t1)
		var p0 := pa.lerp(pb, t0) + side * s0 * w0 * 0.8
		var p1 := pa.lerp(pb, t1) - side * s0 * w1 * 0.8
		_strip(p0, p1, w0 * 0.1, w1 * 0.1, web)


## A screen-space bar from p to q, half-widths wp and wq.
func _strip(p: Vector2, q: Vector2, wp: float, wq: float, colour: Color) -> void:
	var along := q - p
	if along.length() < 0.01:
		return
	var n := Vector2(-along.y, along.x).normalized()
	_fan(PackedVector2Array([p + n * wp, q + n * wq, q - n * wq, p - n * wp]), _same(colour, 4))


func _member_item(i0: int, j0: int, i1: int, j1: int, width: float) -> Item:
	var a := _world(_hull_local(i0, j0, 1.0))
	var b := _world(_hull_local(i1, j1, 1.0))
	var n := _ship_basis * ((_hull_normal(i0, j0) + _hull_normal(i1, j1)).normalized())
	var mid := (a + b) * 0.5
	var col := _metal(ALLOY, mid, n)
	var away := n.dot(_cam - mid) < 0.0
	if away:
		col = _shade(col, 0.6)
	var shine := Color(1.0, 1.0, 0.95, 0.0 if away else 0.5)
	return Item.new(_depth(mid), func() -> void: _girder(a, b, width * SHIP_SCALE, col, shine))


## Doped cloth: matte, with a soft sheen.
func _cloth_shade(p: Vector3, n: Vector3) -> Color:
	var diffuse := maxf(n.dot(_light), 0.0) * (_sun + _moon)
	var view := (_cam - p).normalized()
	var sheen := pow(maxf(n.dot((view + _light).normalized()), 0.0), 6.0) * 0.12 * (_sun + _moon)
	var ambient := (0.62 if not launched else 0.8) * (0.35 + 0.65 * _day)
	var f := ambient + maxf(n.y, 0.0) * 0.12 + diffuse * 0.6
	return Color(CANVAS.r * f + sheen, CANVAS.g * f + sheen, CANVAS.b * f + sheen * 0.8)


func _cloth_item(i: int, j: int) -> Item:
	var jn := (j + 1) % LONGERONS
	# Stretched over the rings, sagging a touch between them.
	var a0 := _hull_local(i, j, 1.012)
	var a1 := _hull_local(i, jn, 1.012)
	var b0 := _hull_local(i + 1, j, 1.012)
	var b1 := _hull_local(i + 1, jn, 1.012)
	var m0 := a0.lerp(b0, 0.5) * 0.992
	var m1 := a1.lerp(b1, 0.5) * 0.992
	var n_a := _ship_basis * _hull_normal(i, j)
	var n_b := _ship_basis * _hull_normal(i + 1, j)
	var n_m := (n_a + n_b).normalized()
	var w: Array[Vector3] = [_world(a0), _world(a1), _world(m0), _world(m1), _world(b0), _world(b1)]
	var centre := (w[0] + w[5]) * 0.5
	var facing := n_m.dot(_cam - centre) > 0.0
	var ca := _cloth_shade(w[0], n_a)
	var cm := _shade(_cloth_shade(w[2], n_m), 0.94)
	var cb := _cloth_shade(w[4], n_b)
	if not facing:
		var inside := _shade(CANVAS, 0.55)
		ca = inside
		cm = _shade(inside, 0.9)
		cb = inside
	var ridge := _shade(ca, 0.82)
	var seam := _shade(ca, 0.9)
	var near := facing and not launched
	return Item.new(_depth(centre), func() -> void:
		_poly([w[0], w[1], w[3], w[2]], [ca, ca, cm, cm])
		_poly([w[2], w[3], w[5], w[4]], [cm, cm, cb, cb])
		if near:
			_beam(w[0], w[1], 0.5, ridge, Color(0, 0, 0, 0))
			_beam(w[0], w[2], 0.25, seam, Color(0, 0, 0, 0))
			_beam(w[2], w[4], 0.25, seam, Color(0, 0, 0, 0)))


func _fin_item(k: int) -> Item:
	var phi := TAU * k / 4.0
	var dir := Vector3(sin(phi), -cos(phi), 0)
	var root_a := Vector3(0, 0, -0.47 * SHIP_L) + dir * _radius(0.03)
	var root_b := Vector3(0, 0, -0.28 * SHIP_L) + dir * _radius(0.22)
	var tip_a := Vector3(0, 0, -0.49 * SHIP_L) + dir * (_radius(0.03) + 11.0)
	var tip_b := Vector3(0, 0, -0.39 * SHIP_L) + dir * (_radius(0.1) + 11.0)
	var pts: Array[Vector3] = [_world(root_a), _world(root_b), _world(tip_b), _world(tip_a)]
	var side := _ship_basis * Vector3(cos(phi), sin(phi), 0)
	var centre := (pts[0] + pts[2]) * 0.5
	if side.dot(_cam - centre) < 0.0:
		side = -side
	var fin_cols: Array[Color] = []
	for k2 in 4:
		fin_cols.append(_shade(_cloth_shade(pts[k2], side), 0.85 if k2 < 2 else 1.0))
	var edge := _metal(ALLOY, centre, side)
	return Item.new(_depth(centre), func() -> void:
		_poly(pts, fin_cols)
		for e in 4:
			_beam(pts[e], pts[(e + 1) % 4], 0.8 * SHIP_SCALE, edge, Color(1, 1, 1, 0.3)))


## A metal cylinder between two local points, as quads that face the camera.
func _cylinder_items(a_l: Vector3, b_l: Vector3, r: float, base: Color, bias: float) -> Array[Item]:
	var items: Array[Item] = []
	var axis := (b_l - a_l).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var segs := 14
	for k in segs:
		var t0 := TAU * k / segs
		var t1 := TAU * (k + 1) / segs
		var o0 := u * cos(t0) + v * sin(t0)
		var o1 := u * cos(t1) + v * sin(t1)
		var quad: Array[Vector3] = [_world(a_l + o0 * r), _world(b_l + o0 * r), _world(b_l + o1 * r), _world(a_l + o1 * r)]
		var n0 := _ship_basis * o0
		var n1 := _ship_basis * o1
		var centre := (quad[0] + quad[2]) * 0.5
		if ((n0 + n1) * 0.5).dot(_cam - centre) <= 0.0:
			continue
		var cols: Array[Color] = [_metal(base, quad[0], n0), _metal(base, quad[1], n0), _metal(base, quad[2], n1), _metal(base, quad[3], n1)]
		items.append(Item.new(_depth(centre) + bias, func() -> void: _poly(quad, cols)))
	# The end facing the camera.
	for at_b: bool in [false, true]:
		var end := b_l if at_b else a_l
		var n := _ship_basis * (axis if at_b else -axis)
		var c := _world(end)
		if n.dot(_cam - c) <= 0.0:
			continue
		var rim: Array[Vector3] = []
		for k in segs:
			var t := TAU * k / segs
			rim.append(_world(end + (u * cos(t) + v * sin(t)) * r))
		var col := _shade(_metal(base, c, n), 0.85)
		items.append(Item.new(_depth(c) + bias - 0.5, func() -> void: _flat(rim, col)))
	return items


const BOILER_A := Vector3(0, -SHIP_R - 8, 44)
const BOILER_B := Vector3(0, -SHIP_R - 8, 60)
const FUNNEL_A := Vector3(0, -SHIP_R - 9, 47)
const FUNNEL_B := Vector3(0, -SHIP_R - 17, 37)


func _engine_hub(k: int) -> Vector3:
	return Vector3((-1.0 if k == 0 else 1.0) * 21.0, -SHIP_R - 9, 84)


func _gondola_items(engines: int) -> Array[Item]:
	var items: Array[Item] = []
	var lo := Vector3(-7, -SHIP_R - 13, 60)
	var hi := Vector3(7, -SHIP_R - 3, 104)
	var wood := Color(0.42, 0.26, 0.15)
	# The cabin: each face drawn only if it faces the camera.
	var faces := [
		[Vector3(-1, 0, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
		[Vector3(1, 0, 0), [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)]],
		[Vector3(0, 0, 1), [Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]],
		[Vector3(0, 0, -1), [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3(0, -1, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)]],
	]
	for face: Array in faces:
		var n := _ship_basis * (face[0] as Vector3)
		var quad: Array[Vector3] = []
		for vtx: Vector3 in face[1]:
			quad.append(_world(vtx))
		var centre := (quad[0] + quad[2]) * 0.5
		if n.dot(_cam - centre) <= 0.0:
			continue
		var col := _metal(wood, centre, n)
		var windows: Array = []
		if absf((face[0] as Vector3).x) > 0.5:
			var x := (face[0] as Vector3).x * 7.05
			for w in 6:
				var z0 := lo.z + 3.0 + w * 7.0
				windows.append([_world(Vector3(x, -SHIP_R - 10, z0)), _world(Vector3(x, -SHIP_R - 6, z0)),
					_world(Vector3(x, -SHIP_R - 6, z0 + 4.0)), _world(Vector3(x, -SHIP_R - 10, z0 + 4.0))])
		items.append(Item.new(_depth(centre) + 2.0, func() -> void:
			_flat(quad, col)
			for e in 4:
				_beam(quad[e], quad[(e + 1) % 4], 0.8 * SHIP_SCALE, _shade(BRASS, 0.9), Color(1, 0.9, 0.7, 0.3))
			for win: Array in windows:
				var wq: Array[Vector3] = []
				for vtx: Vector3 in win:
					wq.append(vtx)
				_flat(wq, Color(1.0, 0.82, 0.48))))
	# The boiler behind the cabin, its funnel angled down and aft.
	items.append_array(_cylinder_items(BOILER_A, BOILER_B, 5.5, BRASS, 1.0))
	items.append_array(_cylinder_items(FUNNEL_A, FUNNEL_B, 1.8, COPPER, 0.5))
	items.append_array(_cylinder_items(FUNNEL_B, FUNNEL_B + (FUNNEL_B - FUNNEL_A).normalized() * 1.5, 2.6, COPPER, 0.4))
	# Hangers up to the keel.
	for x: float in [-6.0, 6.0]:
		for z: float in [48.0, 64.0, 100.0]:
			var a := _world(Vector3(x, -SHIP_R - 3, z))
			var b := _world(Vector3(x * 0.4, -SHIP_R + 1, z))
			var mid := (a + b) * 0.5
			var col := _metal(ALLOY, mid, Vector3.LEFT)
			items.append(Item.new(_depth(mid), func() -> void: _beam(a, b, 0.5 * SHIP_SCALE, col, Color(0, 0, 0, 0))))
	for k in engines:
		items.append_array(_engine_items(k))
	return items


## A steam engine pod on a girder outrigger, fed by a copper pipe from the
## boiler, turning a propeller at its front.
func _engine_items(k: int) -> Array[Item]:
	var items: Array[Item] = []
	var sx := -1.0 if k == 0 else 1.0
	var hub_l := _engine_hub(k)
	var a := _world(Vector3(sx * 7.0, -SHIP_R - 8, 84))
	var b := _world(hub_l + Vector3(-sx * 2.5, 0, 0))
	var mid := (a + b) * 0.5
	var arm := _metal(ALLOY, mid, Vector3.UP)
	items.append(Item.new(_depth(mid) + 1.0, func() -> void: _girder(a, b, 1.6 * SHIP_SCALE, arm, Color(1, 1, 1, 0.4))))
	var pipe_a := _world(BOILER_B + Vector3(sx * 3.0, -2.0, -2.0))
	var pipe_m := _world(Vector3(sx * 7.0, -SHIP_R - 10.5, 84))
	var pipe_b := _world(hub_l + Vector3(0, -1.5, -4))
	var copper := _metal(COPPER, pipe_m, Vector3.UP)
	items.append(Item.new(_depth(pipe_m) + 0.5, func() -> void:
		_beam(pipe_a, pipe_m, 0.7 * SHIP_SCALE, copper, Color(1, 0.8, 0.6, 0.4))
		_beam(pipe_m, pipe_b, 0.7 * SHIP_SCALE, copper, Color(1, 0.8, 0.6, 0.4))))
	items.append_array(_cylinder_items(hub_l + Vector3(0, 0, -7), hub_l + Vector3(0, 0, 5), 3.0, BRASS, 0.0))
	var front := hub_l + Vector3(0, 0, 6)
	var hub := _world(front)
	var blades: Array[Vector3] = []
	for bl in 4:
		var ang := TAU * bl / 4.0 + 0.4
		blades.append(_world(front + Vector3(cos(ang) * 9.0, sin(ang) * 9.0, 0)))
	var rim: Array[Vector3] = []
	for t in 20:
		var ang := TAU * t / 20.0
		rim.append(_world(front + Vector3(cos(ang) * 9.0, sin(ang) * 9.0, 0)))
	var spinning := launched
	items.append(Item.new(_depth(hub) - 1.0, func() -> void:
		var c := _to_cam(hub)
		if c.z <= NEAR:
			return
		if spinning:
			_flat(rim, Color(0.85, 0.80, 0.70, 0.22))
		else:
			for tip: Vector3 in blades:
				_beam(hub, tip, 1.5 * SHIP_SCALE, Color(0.40, 0.25, 0.14), Color(1, 0.85, 0.6, 0.25))
		_disc(_project(c), maxf(_focal * 1.8 * SHIP_SCALE / c.z, 0.6), BRASS)))
	return items


## Smoke from the funnel and steam from the engines, trailing aft and rising.
func _exhaust_items(engines: int) -> Array[Item]:
	var items: Array[Item] = []
	var sources: Array = [[FUNNEL_B, Color(0.22, 0.21, 0.21), 3.0]]
	for k in engines:
		sources.append([_engine_hub(k) + Vector3(0, 2.0, -7), Color(1, 1, 1), 1.6])
	var aft := _ship_basis * Vector3(0, 0, -1)
	for src: Array in sources:
		var origin := _world(src[0] as Vector3)
		var colour := src[1] as Color
		var size := float(src[2])
		for k in 12:
			var p := origin + aft * (k * 16.0 + k * k * 0.8) + Vector3(0, k * 3.0 + k * k * 0.9, 0)
			var r := (size + k * 1.6) * SHIP_SCALE
			var alpha := clampf(0.75 - k * 0.06, 0.0, 1.0)
			items.append(Item.new(_depth(p), func() -> void:
				var c := _to_cam(p)
				if c.z > NEAR:
					var at := _project(c)
					var px := _focal * r / c.z
					_glow(at, px * 1.3, Color(colour, alpha * 0.6))
					_disc(at, px * 0.75, Color(colour, alpha * 0.5))))
	return items


# ------------------------------------------------------------ finishing touches

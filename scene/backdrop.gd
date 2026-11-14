extends Node2D
## The sky, the sun or moon, the stars, the mountains and the ground. Drawn
## again only when the light or the weather changes, never every frame.

const SIZE := 760.0
const HORIZON := 470.0
const GROUND := 640.0

var daylight: Daylight
var cloud := 0.0


func _draw() -> void:
	if daylight == null:
		return
	# Cloud greys the sky out.
	var grey := Color(0.62, 0.65, 0.70)
	var top := daylight.top.lerp(grey * daylight.ambient, cloud * 0.6)
	var bottom := daylight.bottom.lerp(grey * daylight.ambient, cloud * 0.6)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(SIZE, 0), Vector2(SIZE, HORIZON), Vector2(0, HORIZON)]),
		PackedColorArray([top, top, bottom, bottom]))
	_draw_stars()
	_draw_sun_and_moon()
	var lit := 0.45 + 0.55 * daylight.ambient
	var peaks := PackedVector2Array([Vector2(0, HORIZON), Vector2(0, 360), Vector2(110, 300), Vector2(200, 250),
		Vector2(290, 330), Vector2(390, 220), Vector2(520, 340), Vector2(610, 270), Vector2(700, 330),
		Vector2(SIZE, 300), Vector2(SIZE, HORIZON)])
	draw_colored_polygon(peaks, Color(0.58, 0.63, 0.72) * lit)
	for snow: Array in [[Vector2(200, 250), 34.0], [Vector2(390, 220), 44.0], [Vector2(610, 270), 30.0]]:
		var tip := snow[0] as Vector2
		var w := float(snow[1])
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(w * 0.8, w * 0.75), tip + Vector2(w * 0.2, w * 0.55),
			tip + Vector2(-w * 0.3, w * 0.8), tip + Vector2(-w * 0.75, w * 0.7)]), Color(0.95, 0.96, 0.98) * lit)
	var near := Color(0.38, 0.52, 0.34) * lit
	var far := Color(0.30, 0.44, 0.26) * lit
	draw_polygon(PackedVector2Array([Vector2(0, 440), Vector2(SIZE, 430), Vector2(SIZE, SIZE), Vector2(0, SIZE)]),
		PackedColorArray([near, near, far, far]))
	draw_rect(Rect2(330, GROUND - 4, 240, 26), Color(0.30, 0.21, 0.14) * lit)
	draw_rect(Rect2(330, GROUND - 4, 240, 5), Color(0.40, 0.29, 0.19) * lit)


func _draw_stars() -> void:
	var shown := daylight.stars * (1.0 - cloud)
	if shown <= 0.0:
		return
	# The same stars every night: a fixed seed.
	var random := Random.new(7)
	for k in 70:
		var at := Vector2(random.unit() * SIZE, random.unit() * HORIZON * 0.8)
		draw_circle(at, 0.6 + random.unit() * 0.9, Color(1, 1, 0.95, shown * (0.4 + 0.6 * random.unit())))


func _draw_sun_and_moon() -> void:
	var veil := 1.0 - cloud * 0.85
	if daylight.sun_up:
		var sun := Vector2(40 + daylight.sun_x * (SIZE - 80), HORIZON - 30 - daylight.elevation * 360)
		draw_circle(sun, 58, Color(1, 1, 0.95, 0.10 * veil))
		draw_circle(sun, 38, Color(1, 1, 0.95, 0.18 * veil))
		draw_circle(sun, 21, Color(1.0, 0.98, 0.88, veil))
	elif daylight.moon_elevation > 0.0:
		var moon := Vector2(40 + daylight.moon_x * (SIZE - 80), HORIZON - 30 - daylight.moon_elevation * 330)
		draw_circle(moon, 30, Color(0.85, 0.88, 1.0, 0.08 * veil))
		draw_circle(moon, 14, Color(0.92, 0.93, 0.98, veil))

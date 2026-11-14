extends Node2D
## Laid over the whole scene: cloud, fog, rain and snow, then the night's
## blue and the golden hour's warmth. Drawn still (milestone 5 sets the rain
## and snow moving), and again only when the light or the weather changes.

const SIZE := 760.0

var daylight: Daylight
var conditions := Weather.Conditions.new()


func _draw() -> void:
	if daylight == null:
		return
	var lit := 0.45 + 0.55 * daylight.ambient
	# The same clouds, streaks and flakes each time: fixed seeds.
	if conditions.cloud > 0.0:
		var random := Random.new(11)
		for k in 7:
			var at := Vector2(random.unit() * SIZE, 60 + random.unit() * 220)
			var size := Vector2(110 + random.unit() * 120, 34 + random.unit() * 26)
			var colour := Color(0.88, 0.89, 0.92) * lit
			_ellipse(at, size, Color(colour, 0.55 * conditions.cloud))
			_ellipse(at + Vector2(size.x * 0.3, -size.y * 0.35), size * 0.6, Color(colour, 0.45 * conditions.cloud))
	if conditions.rain > 0.0:
		var random := Random.new(13)
		for k in 160:
			var top := Vector2(random.unit() * SIZE, random.unit() * SIZE)
			draw_line(top, top + Vector2(-6, 22), Color(0.75, 0.82, 0.92, 0.45 * conditions.rain), 1.2, true)
	if conditions.snow > 0.0:
		var random := Random.new(17)
		for k in 180:
			draw_circle(Vector2(random.unit() * SIZE, random.unit() * SIZE), 1.2 + random.unit() * 1.8,
				Color(1, 1, 1, 0.85 * conditions.snow))
	if conditions.fog > 0.0:
		var thin := Color(0.86, 0.88, 0.9, 0.0)
		var thick := Color(0.86, 0.88, 0.9, 0.7 * conditions.fog) * Color(lit, lit, lit, 1.0)
		draw_polygon(PackedVector2Array([Vector2(0, 200), Vector2(SIZE, 200), Vector2(SIZE, SIZE), Vector2(0, SIZE)]),
			PackedColorArray([thin, thin, thick, thick]))
	draw_rect(Rect2(0, 0, SIZE, SIZE), daylight.night_tint())
	draw_rect(Rect2(0, 0, SIZE, SIZE), daylight.warm_tint())


func _ellipse(centre: Vector2, size: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for k in 24:
		var angle := TAU * k / 24.0
		points.append(centre + Vector2(cos(angle) * size.x, sin(angle) * size.y) * 0.5)
	draw_colored_polygon(points, colour)

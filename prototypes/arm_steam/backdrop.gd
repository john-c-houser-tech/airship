extends Node2D
## Milestone 3 prototype, throwaway: everything in the arm scene that never
## moves (sky, mountains, the boiler's body, the hopper's stand), drawn once.
## Godot keeps the drawing and shows it every frame without redrawing it.

const SIZE := 760.0
const GROUND := 640.0
const GAUGE := Vector2(73, 505)
const BRASS := Color(0.82, 0.60, 0.27)
const BRASS_DARK := Color(0.50, 0.33, 0.14)
const COPPER := Color(0.74, 0.42, 0.25)
const IRON := Color(0.24, 0.22, 0.21)
const SKY_TOP := Color(0.25, 0.43, 0.67)
const SKY_LOW := Color(0.72, 0.81, 0.90)


func _draw() -> void:
	_draw_land()
	_draw_boiler()
	draw_line(Vector2(610, GROUND), Vector2(618, 520), IRON, 5.0)
	draw_line(Vector2(672, GROUND), Vector2(664, 520), IRON, 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(596, 470), Vector2(686, 470), Vector2(664, 522), Vector2(618, 522)]), BRASS_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(600, 474), Vector2(682, 474), Vector2(678, 484), Vector2(604, 484)]), Color(0.18, 0.13, 0.09))


func _draw_land() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(SIZE, 0), Vector2(SIZE, 470), Vector2(0, 470)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	var peaks := PackedVector2Array([Vector2(0, 470), Vector2(0, 360), Vector2(110, 300), Vector2(200, 250),
		Vector2(290, 330), Vector2(390, 220), Vector2(520, 340), Vector2(610, 270), Vector2(700, 330),
		Vector2(SIZE, 300), Vector2(SIZE, 470)])
	draw_colored_polygon(peaks, Color(0.58, 0.63, 0.72))
	for snow: Array in [[Vector2(200, 250), 34.0], [Vector2(390, 220), 44.0], [Vector2(610, 270), 30.0]]:
		var tip := snow[0] as Vector2
		var w := float(snow[1])
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(w * 0.8, w * 0.75), tip + Vector2(w * 0.2, w * 0.55),
			tip + Vector2(-w * 0.3, w * 0.8), tip + Vector2(-w * 0.75, w * 0.7)]), Color(0.95, 0.96, 0.98))
	draw_polygon(PackedVector2Array([Vector2(0, 440), Vector2(SIZE, 430), Vector2(SIZE, SIZE), Vector2(0, SIZE)]),
		PackedColorArray([Color(0.38, 0.52, 0.34), Color(0.38, 0.52, 0.34), Color(0.30, 0.44, 0.26), Color(0.30, 0.44, 0.26)]))
	draw_rect(Rect2(330, GROUND - 4, 240, 26), Color(0.30, 0.21, 0.14))
	draw_rect(Rect2(330, GROUND - 4, 240, 5), Color(0.40, 0.29, 0.19))


func _draw_boiler() -> void:
	var body := Rect2(30, 430, 86, 210)
	var cols := PackedColorArray([BRASS_DARK, BRASS.lightened(0.2), BRASS_DARK.darkened(0.2), BRASS_DARK])
	draw_polygon(PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]),
		PackedColorArray([cols[0], cols[1], cols[1], cols[0]]))
	draw_circle(Vector2(73, 430), 43, BRASS.darkened(0.1))
	for y: float in [470.0, 540.0, 610.0]:
		draw_line(Vector2(30, y), Vector2(116, y), BRASS_DARK.darkened(0.3), 3.0)
		for x in range(36, 116, 12):
			draw_circle(Vector2(x, y - 4), 1.8, BRASS_DARK.darkened(0.4))
	draw_rect(Rect2(46, 590, 54, 30), IRON)
	draw_circle(GAUGE, 17, Color(0.95, 0.92, 0.84))
	draw_arc(GAUGE, 17, 0, TAU, 32, BRASS_DARK, 3.0, true)
	# The valve on top, and the steam pipe over to the arm.
	draw_rect(Rect2(64, 396, 16, 14), BRASS_DARK)
	var pipe := PackedVector2Array([Vector2(116, 560), Vector2(180, 560), Vector2(180, 612), Vector2(222, 612)])
	draw_polyline(pipe, COPPER.darkened(0.2), 9.0, true)
	draw_polyline(pipe, COPPER.lightened(0.1), 3.0, true)

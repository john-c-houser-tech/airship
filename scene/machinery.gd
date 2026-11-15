extends Node2D
## The machinery that never moves: the planter, the boiler's body and the
## hopper's stand. Drawn once; the window dims it to the hangar's light.

const GROUND := 640.0
const GAUGE := Vector2(73, 505)
const BRASS := Color(0.82, 0.60, 0.27)
const BRASS_DARK := Color(0.50, 0.33, 0.14)
const COPPER := Color(0.74, 0.42, 0.25)
const IRON := Color(0.24, 0.22, 0.21)


func _draw() -> void:
	_draw_planter()
	_draw_boiler()
	draw_line(Vector2(610, GROUND), Vector2(618, 520), IRON, 5.0)
	draw_line(Vector2(672, GROUND), Vector2(664, 520), IRON, 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(596, 470), Vector2(686, 470), Vector2(664, 522), Vector2(618, 522)]), BRASS_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(600, 474), Vector2(682, 474), Vector2(678, 484), Vector2(604, 484)]), Color(0.18, 0.13, 0.09))


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


## The planter on the hangar's boards that the arm builds in, and the shadow
## the machinery casts on them.
func _draw_planter() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-40, 655), Vector2(720, 655), Vector2(700, 700), Vector2(-20, 700)]),
		Color(0, 0, 0, 0.25))
	draw_rect(Rect2(320, 626, 260, 40), Color(0.34, 0.22, 0.13))
	draw_rect(Rect2(320, 626, 260, 6), Color(0.46, 0.31, 0.19))
	draw_rect(Rect2(330, 632, 240, 8), Color(0.24, 0.17, 0.11))
	for x: float in [320.0, 576.0]:
		draw_rect(Rect2(x, 626, 4, 40), BRASS.darkened(0.1))

extends Node2D
## Milestone 0 stand-in: the hangar's open doors as two flat colours, plus a
## frame grab the tests use. The real scene starts with milestone 1.
##
## `-- --shot=<path>` draws a few frames, saves the last one as a PNG, checks
## two pixels and quits: exit code 0 if the frame looks right, 1 if not.

const WOOD := Color(0.36, 0.24, 0.14)
const SKY := Color(0.55, 0.72, 0.88)
const FRAMES_BEFORE_SHOT := 3

var _shot_path := ""
var _frames := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
	get_viewport().size_changed.connect(queue_redraw)
	set_process(not _shot_path.is_empty())


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), WOOD)
	draw_rect(Rect2(size * Vector2(0.2, 0.25), size * Vector2(0.6, 0.75)), SKY)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < FRAMES_BEFORE_SHOT:
		return
	set_process(false)
	var image := get_viewport().get_texture().get_image()
	image.save_png(_shot_path)
	var middle := image.get_pixel(int(image.get_width() * 0.5), int(image.get_height() * 0.5))
	var corner := image.get_pixel(4, 4)
	var ok := _near(middle, SKY) and _near(corner, WOOD)
	if not ok:
		printerr("frame check failed: middle %s, corner %s" % [middle, corner])
	get_tree().quit(0 if ok else 1)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

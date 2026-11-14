extends Node2D
## The words on screen: the countdown while the arm builds, one line saying
## what is happening and what to do next, and a line when the garden can't
## be saved. Plain words, never the design's terms.

const SIZE := 760.0

var state := Session.State.IDLE
var remaining := 0
var garden_problem := Garden.Problem.NONE
var save_error := ""
var notices_work := true


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if state == Session.State.BUILDING:
		var text := "%d:%02d" % [floori(remaining / 60.0), remaining % 60]
		_shadowed(font, Vector2(0, 50), text, 34, HORIZONTAL_ALIGNMENT_RIGHT)
	_shadowed(font, Vector2(0, SIZE - 24), _next_step(), 16, HORIZONTAL_ALIGNMENT_CENTER)
	var problem := _problem()
	if not problem.is_empty():
		_shadowed(font, Vector2(0, SIZE - 50), problem, 13, HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 0.85, 0.6))


## What is happening, and the one thing to do next.
func _next_step() -> String:
	match state:
		Session.State.BUILDING:
			return "Building. Stay with your work; press Space only to give up."
		Session.State.BUILT:
			return "Built. Take a five-minute break, then press Space to build again."
		Session.State.RUSTED:
			return "Left to rust. Press Space to start building again."
	return "Press Space to start 25 minutes of focus while the arm builds."


func _problem() -> String:
	match garden_problem:
		Garden.Problem.CANNOT_OPEN:
			return "Your garden file can't be opened, so new plants aren't being saved."
		Garden.Problem.CANNOT_READ:
			return "Your garden file can't be read, so it's left as it is and new plants aren't saved."
		Garden.Problem.NO_FOLDER:
			return "There's no folder to keep your garden in, so plants aren't being saved."
		Garden.Problem.BUSY:
			return "Another Airship is saving the garden; this plant will be saved with the next."
		Garden.Problem.CANNOT_SAVE:
			return "Your garden couldn't be saved: %s. It will try again with the next plant." % save_error
	if not notices_work:
		return "Desktop notices can't be sent (notify-send is missing)."
	return ""


func _shadowed(font: Font, at: Vector2, text: String, size: int, align: HorizontalAlignment,
		colour := Color(1, 1, 1, 0.95)) -> void:
	var inset := 24.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0
	draw_string(font, at + Vector2(1, 1), text, align, SIZE - inset, size, Color(0, 0, 0, 0.55))
	draw_string(font, at, text, align, SIZE - inset, size, colour)

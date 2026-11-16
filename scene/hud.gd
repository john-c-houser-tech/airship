extends Node2D
## The words on screen: the countdown while the arm builds, one line saying
## what is happening and what to do next (in the break after a session, its
## steps one at a time), between sessions which plant comes
## next and how to choose another, and a line when the garden can't be
## saved. Plain words, never the design's terms.

const SIZE := 760.0

var state := Session.State.IDLE
var remaining := 0
var garden_problem := Garden.Problem.NONE
var save_error := ""
var notices_work := true
var muted := false
## The plant the next session builds (Parts.Kind).
var next_plant := 0
## What the break asks for next (App.BreakStep), and the plant it's about.
var break_step := App.BreakStep.NONE
var new_plant := 0
## Where the valley's commissions stand (App.commissions()).
var commissions: Commissions.State = null
## The parts the night train would take and bring (Parts.Kind).
var trade_gives := 0
var trade_brings := 0
## Says each line in the current language.
var catalog := Catalog.new("en")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if state == Session.State.BUILDING:
		var text := "%d:%02d" % [floori(remaining / 60.0), remaining % 60]
		_shadowed(font, Vector2(0, 50), text, 34, HORIZONTAL_ALIGNMENT_RIGHT)
	# Lines run longer in some languages: they wrap, and stack up from the
	# bottom edge.
	var top := SIZE - 16
	if state != Session.State.BUILDING and break_step != App.BreakStep.NONE and break_step != App.BreakStep.TRADE:
		# A step of the break can always be left for later.
		top = _wrapped(font, top, catalog.translate("Or press Space to build again."), 13, Color(1, 1, 1, 0.75)) - 2
	top = _wrapped(font, top, next_step(), 16, Color(1, 1, 1, 0.95))
	if state != Session.State.BUILDING:
		top = _wrapped(font, top - 6, next_plant_line(), 14, Color(1, 1, 1, 0.85))
		var asked := commission_line()
		if not asked.is_empty():
			top = _wrapped(font, top - 4, asked, 13, Color(1, 1, 1, 0.75))
	var problem := _problem()
	if not problem.is_empty():
		_wrapped(font, top - 8, problem, 13, Color(1.0, 0.85, 0.6))


## What is happening, and the one thing to do next.
func next_step() -> String:
	match break_step if state != Session.State.BUILDING else App.BreakStep.NONE:
		App.BreakStep.PLANT:
			var plant := catalog.translate(Parts.PLANT_NAMES[new_plant])
			return catalog.translate("Built. Click the garden through the door, or press Enter, to plant your new %s.") % plant
		App.BreakStep.SCRAPE:
			return catalog.translate("A plant in the garden has seized with rust. Click the garden, or press Enter, to scrape it clean.")
		App.BreakStep.COLLECT:
			return catalog.translate("Your plants have made parts. Click the garden, or press Enter, to collect them.")
		App.BreakStep.TRADE:
			var gives := catalog.translate(Parts.PART_NAMES[trade_gives])
			var brings := catalog.translate(Parts.PART_NAMES[trade_brings])
			return catalog.translate("The night train offers a trade: it takes three parts your garden can best spare (%s) and brings one it is slowest to make (%s). To trade, click through the door or press T; or press Space to build again, and the train moves on.") % [gives, brings]
		App.BreakStep.FIT:
			return catalog.translate("You have parts for the airship. Click the airship, or press Enter, to fit them.")
		App.BreakStep.LAUNCH:
			return catalog.translate("The airship is finished! Press L to launch it over the pass. It won't come back: a new valley begins.")
	match state:
		Session.State.BUILDING:
			return catalog.translate("Building. Stay with your work; press Space only to give up.")
		Session.State.BUILT:
			return catalog.translate("Built. Take a five-minute break, then press Space to build again.")
		Session.State.RUSTED:
			return catalog.translate("Left to rust. Press Space to start building again.")
	return catalog.translate("Press Space to start 25 minutes of focus while the arm builds.")


## What the visiting airship asks for, and how far along it is; nothing
## before the valley's first commission.
func commission_line() -> String:
	if commissions == null or commissions.open == null:
		return ""
	var asked := commissions.open
	var plant := catalog.translate(Parts.PLANT_NAMES[asked.kind])
	var weather := catalog.translate(Commissions.WEATHER_PHRASES[asked.weather])
	return catalog.translate("A visiting airship's commission, no hurry: %d × %s, built %s. Built so far: %d. Pennants won: %d.") % [asked.count, plant, weather, asked.done, commissions.met]


## Which plant the arm builds next, what it makes, and how to choose.
func next_plant_line() -> String:
	var plant := catalog.translate(Parts.PLANT_NAMES[next_plant])
	var part := catalog.translate(Parts.PART_NAMES[next_plant])
	return catalog.translate("Next plant: %s, which makes %s. Press Left or Right to choose another.") % [plant, part]


func _problem() -> String:
	match garden_problem:
		Garden.Problem.CANNOT_OPEN:
			return catalog.translate("Your garden file can't be opened, so new plants aren't being saved.")
		Garden.Problem.CANNOT_READ:
			return catalog.translate("Your garden file can't be read, so it's left as it is and new plants aren't saved.")
		Garden.Problem.NO_FOLDER:
			return catalog.translate("There's no folder to keep your garden in, so plants aren't being saved.")
		Garden.Problem.BUSY:
			return catalog.translate("Another Airship is saving the garden; this plant will be saved with the next.")
		Garden.Problem.CANNOT_SAVE:
			# The garden's own reasons are translated; the system's own words
			# (a disk error) come through as they are.
			return catalog.translate("Your garden couldn't be saved: %s. It will try again with the next plant.") \
				% catalog.translate(save_error)
	if not notices_work:
		return catalog.translate("Desktop notices can't be sent (notify-send is missing).")
	if muted:
		return catalog.translate("Sounds are off. Press M to turn them on.")
	return ""


func _shadowed(font: Font, at: Vector2, text: String, size: int, align: HorizontalAlignment,
		colour := Color(1, 1, 1, 0.95)) -> void:
	var inset := 24.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0
	draw_string(font, at + Vector2(1, 1), text, align, SIZE - inset, size, Color(0, 0, 0, 0.55))
	draw_string(font, at, text, align, SIZE - inset, size, colour)


## Draws text centred and wrapped to the window, its last line ending at
## `bottom`. Returns where its first line's top is.
func _wrapped(font: Font, bottom: float, text: String, size: int, colour: Color) -> float:
	var width := SIZE - 48.0
	var height := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, size).y
	var top := bottom - height
	var at := Vector2(24, top + font.get_ascent(size))
	draw_multiline_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, Color(0, 0, 0, 0.55))
	draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, colour)
	return top

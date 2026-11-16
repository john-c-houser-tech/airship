extends Node2D
## The words on screen. Left alone, almost none: the countdown while the
## arm builds, a small reminder of the key for help, and a line when the
## garden can't be saved. H unfurls a banner from a brass rod at the top
## with everything else, laid out to be read: what is happening and the
## one thing to do next (in the break after a session, its steps one at a
## time), which plant comes next, what a visiting airship has asked for,
## and the keys that do something now. Plain words, never the design's
## terms.

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
## How far the help banner is unfurled, 0 (rolled up) to 1: the window
## moves it when H is pressed.
var unfurled := 0.0
## Says each line in the current language.
var catalog := Catalog.new("en")


const BANNER_WIDTH := 560.0
const BANNER_TOP := 22.0
const BANNER_PAD := 24.0
const KEY_COLUMN := 150.0
const INK := Color(0.21, 0.14, 0.09)
const CLOTH := Color(0.91, 0.86, 0.73)


## One thing on the banner: a paragraph, a ruled line, or a key and what it
## does.
class Entry:
	var text := ""
	var key := ""
	var size := 14
	var rule := false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var problem := _problem()
	var top := SIZE - 16
	if not problem.is_empty():
		top = _wrapped(font, top, problem, 13, Color(1.0, 0.85, 0.6)) - 4
	if unfurled > 0.0:
		_draw_banner(font)
		return
	if state == Session.State.BUILDING:
		_shadowed(font, Vector2(0, 50), _countdown(), 34, HORIZONTAL_ALIGNMENT_RIGHT)
	# Rolled up: only where to find it, brighter when the break has
	# something waiting.
	var waiting := state != Session.State.BUILDING and break_step != App.BreakStep.NONE
	_shadowed(font, Vector2(0, top - 2), catalog.translate("Something to do: press H.") if waiting
		else catalog.translate("Press H for help."), 13 if waiting else 12, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.9 if waiting else 0.6))


## The time left in the session.
func _countdown() -> String:
	return "%d:%02d" % [floori(remaining / 60.0), remaining % 60]


## What the banner says now, top to bottom.
func banner_entries() -> Array[Entry]:
	var entries: Array[Entry] = []
	var building := state == Session.State.BUILDING
	var step := App.BreakStep.NONE if building else break_step
	if building:
		# The countdown's corner is behind the cloth: it heads the banner.
		entries.append(_paragraph(_countdown(), 26))
	entries.append(_paragraph(next_step(), 17))
	if not building:
		entries.append(_paragraph(next_plant_line(), 14))
		var asked := commission_line()
		if not asked.is_empty():
			entries.append(_paragraph(asked, 14))
	if muted:
		entries.append(_paragraph(catalog.translate("Sounds are off. Press M to turn them on."), 14))
	var ruled := Entry.new()
	ruled.rule = true
	entries.append(ruled)
	# Only the keys that do something now.
	entries.append(_key(catalog.translate("Space"),
		catalog.translate("give up this session") if building else catalog.translate("start 25 minutes of focus")))
	if not building:
		entries.append(_key(catalog.translate("Left, Right"), catalog.translate("choose the next plant")))
	if step in [App.BreakStep.PLANT, App.BreakStep.SCRAPE, App.BreakStep.COLLECT, App.BreakStep.FIT]:
		entries.append(_key(catalog.translate("Enter key"), catalog.translate("take the break's next step")))
	if step == App.BreakStep.TRADE:
		entries.append(_key("T", catalog.translate("trade with the night train")))
	if step == App.BreakStep.LAUNCH:
		entries.append(_key("L", catalog.translate("launch the airship")))
	entries.append(_key("M", catalog.translate("turn the sounds on") if muted else catalog.translate("turn the sounds off")))
	entries.append(_key("H", catalog.translate("roll this banner up")))
	return entries


func _paragraph(text: String, size: int) -> Entry:
	var entry := Entry.new()
	entry.text = text
	entry.size = size
	return entry


func _key(key: String, does: String) -> Entry:
	var entry := Entry.new()
	entry.key = key
	entry.text = does
	return entry


## How tall an entry stands on the banner, with the gap under it.
func _entry_height(font: Font, entry: Entry) -> float:
	if entry.rule:
		return 16.0
	var width := BANNER_WIDTH - 2.0 * BANNER_PAD - (KEY_COLUMN if not entry.key.is_empty() else 0.0)
	var height := font.get_multiline_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, width, entry.size).y
	return (maxf(height, 24.0) + 6.0) if not entry.key.is_empty() else height + 10.0


## The banner: cloth hanging from a brass rod, as much of it as is
## unfurled, its roll at the bottom until it is all down. An entry shows
## once the cloth has reached below it.
func _draw_banner(font: Font) -> void:
	var entries := banner_entries()
	var full := 2.0 * BANNER_PAD - 6.0
	for entry: Entry in entries:
		full += _entry_height(font, entry)
	var left := (SIZE - BANNER_WIDTH) * 0.5
	# Easing out: quick at first, settling at the end.
	var shown := 1.0 - pow(1.0 - clampf(unfurled, 0.0, 1.0), 3.0)
	var bottom := BANNER_TOP + full * shown
	draw_rect(Rect2(left + 4, BANNER_TOP + 4, BANNER_WIDTH, bottom - BANNER_TOP), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(left, BANNER_TOP, BANNER_WIDTH, bottom - BANNER_TOP), CLOTH)
	# A hem down each side, and a point cut into the bottom edge.
	for x: float in [left + 7.0, left + BANNER_WIDTH - 8.0]:
		draw_line(Vector2(x, BANNER_TOP), Vector2(x, bottom), CLOTH.darkened(0.18), 1.0)
	if shown >= 1.0:
		draw_colored_polygon(PackedVector2Array([Vector2(left, bottom), Vector2(left + BANNER_WIDTH, bottom),
			Vector2(left + BANNER_WIDTH, bottom + 16), Vector2(SIZE * 0.5, bottom + 4), Vector2(left, bottom + 16)]), CLOTH)
	else:
		# Still rolled at the bottom.
		draw_rect(Rect2(left - 5, bottom - 7, BANNER_WIDTH + 10, 14), CLOTH.darkened(0.22))
		draw_rect(Rect2(left - 5, bottom - 7, BANNER_WIDTH + 10, 4), CLOTH.darkened(0.08))
	# The rod, with a knob at each end.
	var brass := Color(0.80, 0.58, 0.26)
	draw_rect(Rect2(left - 16, BANNER_TOP - 9, BANNER_WIDTH + 32, 9), brass.darkened(0.25))
	draw_rect(Rect2(left - 16, BANNER_TOP - 9, BANNER_WIDTH + 32, 3), brass.lightened(0.2))
	for x: float in [left - 18.0, left + BANNER_WIDTH + 18.0]:
		draw_circle(Vector2(x, BANNER_TOP - 4.5), 7.5, brass)
		draw_circle(Vector2(x - 2, BANNER_TOP - 6.5), 2.5, brass.lightened(0.35))
	var y := BANNER_TOP + BANNER_PAD - 6.0
	var x0 := left + BANNER_PAD
	var width := BANNER_WIDTH - 2.0 * BANNER_PAD
	for entry: Entry in entries:
		var height := _entry_height(font, entry)
		if y + height > bottom - 4.0:
			break
		if entry.rule:
			draw_line(Vector2(x0, y + 5), Vector2(x0 + width, y + 5), Color(INK, 0.35), 1.0)
		elif entry.key.is_empty():
			draw_multiline_string(font, Vector2(x0, y + font.get_ascent(entry.size)), entry.text, HORIZONTAL_ALIGNMENT_LEFT,
				width, entry.size, -1, INK)
		else:
			# The key as a brass-edged cap, what it does beside it.
			var cap := font.get_string_size(entry.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
			draw_rect(Rect2(x0, y, cap, 22), Color(INK, 0.9))
			draw_rect(Rect2(x0 + 1.5, y + 1.5, cap - 3, 19), CLOTH.lightened(0.25))
			draw_string(font, Vector2(x0 + 9, y + 16), entry.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
			draw_multiline_string(font, Vector2(x0 + KEY_COLUMN, y + 3 + font.get_ascent(14)), entry.text,
				HORIZONTAL_ALIGNMENT_LEFT, width - KEY_COLUMN, 14, -1, INK)
		y += height


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

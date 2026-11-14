extends Control
## Milestone 1 prototype, throwaway: the 5-minute break after a focus session.
## Placeholder shapes only. It answers gate A: is the break fun, and does it
## fit in 5 minutes?
##
## A banner at the top always says the one next thing to do. Whatever can be
## clicked glows; every click shows its result (a flash, parts floating into
## or out of the parts box).
##
## Run it: godot --path . res://prototypes/break_task/break_task.tscn
## Flags after `--`: --sessions=N works N sessions first (the last one's break
## is left to do); --clicks=X,Y;X,Y clicks those points, one per frame, through
## Godot's input like a real mouse; --shot=PATH saves a frame (after any
## clicks) and quits; --log-input prints every click and every change to
## Godot's log.

enum Phase { CHOOSE, BREAK, LAUNCHED }

const BREAK_SECONDS := 300.0
const SLOTS := 6
const SHOT_FRAMES := 3
const FONT_SMALL := 13

const WOOD := Color(0.30, 0.20, 0.12)
const FLOOR := Color(0.22, 0.16, 0.11)
const SKY := Color(0.55, 0.72, 0.88)
const HILLS := Color(0.45, 0.50, 0.58)
const GRASS := Color(0.36, 0.48, 0.30)
const SOIL := Color(0.32, 0.24, 0.16)
const BRASS := Color(0.86, 0.68, 0.30)
const RUST := Color(0.80, 0.42, 0.26)
const LINE := Color(0.85, 0.80, 0.70)
const DARK_TEXT := Color(0.12, 0.09, 0.05)

const BANNER := Rect2(0, 0, 760, 44)
const DOORWAY := Rect2(140, 52, 480, 268)
const GROUND_TOP := 200.0
const PLOT := Rect2(296, 200, 316, 120)
const ARM := Rect2(16, 330, 168, 94)
const BOX := Rect2(576, 330, 168, 94)
const RESULT := Rect2(16, 430, 728, 22)
const GOAL := Rect2(8, 60, 124, 252)
const HOW := Rect2(628, 60, 124, 252)
const STATUS := Rect2(16, 646, 728, 18)
const WORK := Rect2(16, 724, 300, 32)
const STOP := Rect2(328, 724, 150, 32)
const BACK := Rect2(16, 684, 220, 36)
const LAUNCH := Rect2(250, 684, 220, 36)
const OVER := Rect2(16, 684, 160, 36)


class Kind:
	var name: String
	var part: String
	var colour: Color

	func _init(name_: String, part_: String, colour_: Color) -> void:
		name = name_
		part = part_
		colour = colour_


class Plant:
	var kind: Kind
	var rusted: bool
	var stock := 0

	func _init(kind_: Kind, rusted_: bool) -> void:
		kind = kind_
		rusted = rusted_


class Piece:
	var name: String
	var needs: Dictionary
	var rect: Rect2
	var built := false

	func _init(name_: String, needs_: Dictionary, rect_: Rect2) -> void:
		name = name_
		needs = needs_
		rect = rect_


var _kinds: Array[Kind] = []
var _pieces: Array[Piece] = []
var _garden: Array[Plant] = []
var _box := {"cog": 0, "tubing": 0, "plate": 0}
var _phase := Phase.CHOOSE
var _chosen: Kind = null
var _held: Plant = null
var _worked := 0
var _stopped := 0
var _last_worked := false
var _break_left := 0.0
var _done_at := -1.0
var _result := ""

var _banner: Label
var _result_label: Label
var _status: Label
var _dynamic: Control
var _fx: Control
var _shot_path := ""
var _frames := 0
var _clicks: Array[Vector2] = []
var _log_input := false


func _init() -> void:
	_kinds = [
		Kind.new("Gear-flower", "cog", Color(0.98, 0.80, 0.36)),
		Kind.new("Pipe-vine", "tubing", Color(0.95, 0.60, 0.38)),
		Kind.new("Sheet-fern", "plate", Color(0.82, 0.88, 0.92)),
	]
	_pieces = [
		Piece.new("Bow", {"plate": 2}, Rect2(110, 460, 180, 56)),
		Piece.new("Balloon", {"plate": 3}, Rect2(296, 460, 180, 56)),
		Piece.new("Stern", {"plate": 2}, Rect2(482, 460, 180, 56)),
		Piece.new("Keel", {"tubing": 3}, Rect2(150, 524, 240, 56)),
		Piece.new("Ribs", {"tubing": 2, "cog": 1}, Rect2(396, 524, 240, 56)),
		Piece.new("Cabin", {"plate": 2, "tubing": 1}, Rect2(58, 588, 160, 56)),
		Piece.new("Engine", {"cog": 3, "tubing": 1}, Rect2(224, 588, 160, 56)),
		Piece.new("Propeller", {"cog": 2}, Rect2(390, 588, 160, 56)),
		Piece.new("Rudder", {"plate": 1, "cog": 1}, Rect2(556, 588, 160, 56)),
	]
	_garden.resize(SLOTS)
	_chosen = _kinds[0]


func _ready() -> void:
	var sessions := 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--clicks="):
			for point: String in arg.trim_prefix("--clicks=").split(";"):
				var xy := point.split(",")
				_clicks.append(Vector2(xy[0].to_float(), xy[1].to_float()))
		elif arg == "--log-input":
			_log_input = true
		elif arg.begins_with("--sessions="):
			sessions = arg.trim_prefix("--sessions=").to_int()
	_banner = _label(BANNER.grow_individual(-16, -10, -16, -6), 18)
	_banner.add_theme_color_override("font_color", BRASS.lightened(0.35))
	_label(GOAL.grow(-8), FONT_SMALL, "YOUR GOAL\n\nGrow the parts you need to build an airship, then fly it out over the mountains.")
	_label(HOW.grow(-8), FONT_SMALL, "HOW IT WORKS\n\n1. Work for 25 minutes.\n2. Your plants grow parts.\n3. On your break, build the airship.")
	_result_label = _label(RESULT, 14)
	_status = _label(STATUS, FONT_SMALL)
	_status.add_theme_color_override("font_color", LINE.darkened(0.25))
	_dynamic = Control.new()
	_fx = Control.new()
	for layer: Control in [_dynamic, _fx]:
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	for i: int in sessions:
		_chosen = _kinds[i % _kinds.size()]
		_work()
		if i < sessions - 1:
			_do_every_task()
	_refresh()


func _process(delta: float) -> void:
	if _phase == Phase.BREAK:
		_break_left = maxf(_break_left - delta, 0.0)
		if _break_left == 0.0:
			_phase = Phase.CHOOSE
			_result = "The break is over."
			_refresh()
		else:
			_update_text()
	queue_redraw()  # the glow pulses
	_frames += 1
	if _frames >= SHOT_FRAMES and not _clicks.is_empty():
		_click(_clicks.pop_front())
	elif not _shot_path.is_empty() and _frames >= SHOT_FRAMES:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if _log_input and event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		print("input: button %d %s at %s" % [e.button_index, "down" if e.pressed else "up", e.position])


func _click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)


# What the player should do now, in their words: one thing at a time.
func _next_step() -> String:
	match _phase:
		Phase.CHOOSE:
			return "Pick a seed for the robot arm, then press \"Work for 25 minutes\"."
		Phase.LAUNCHED:
			return "Your airship flew out over the pass! Press \"Start over\" to play again."
	if _held != null:
		var what := "rusty " + _held.kind.name if _held.rusted else "new " + _held.kind.name
		if _garden_full():
			return "The garden is full. Click a plant to swap it for your %s." % what
		return "Click a glowing square in the garden to plant your %s." % what
	for plant: Plant in _garden:
		if plant != null and plant.stock > 0:
			return "Your plants grew parts. Click a glowing plant to pick them."
	for plant: Plant in _garden:
		if plant != null and plant.rusted and _last_worked:
			return "Click the rusty plant to scrape the rust off."
	for piece: Piece in _pieces:
		if _piece_usable(piece):
			return "You have the parts for the %s. Click it to build it onto the airship." % piece.name
	if _built_count() == _pieces.size():
		return "The airship is finished! Press \"Launch the airship\"."
	return "All done for this break. Press \"Back to work\" when you're ready."


func _work() -> void:
	_worked += 1
	_last_worked = true
	for plant: Plant in _garden:
		if plant != null and not plant.rusted:
			plant.stock += 1
	_held = Plant.new(_chosen, false)
	_result = "25 minutes of work done. The robot arm built a %s." % _chosen.name
	_start_break()


func _stop_early() -> void:
	_stopped += 1
	_last_worked = false
	_held = Plant.new(_chosen, true)
	_result = "You stopped early. No steam, so nothing grew, and the half-built %s rusted." % _chosen.name
	_start_break()


func _start_break() -> void:
	_phase = Phase.BREAK
	_break_left = BREAK_SECONDS
	_done_at = -1.0


func _on_slot(i: int) -> void:
	var plant: Plant = _garden[i]
	var rect := _slot_rect(i)
	if _held != null and (plant == null or _garden_full()):
		if plant != null:
			_pick(plant, rect)
		_result = "You planted the %s." % _held.kind.name
		_garden[i] = _held
		_held = null
		_flash(rect)
	elif plant != null and plant.stock > 0:
		_result = "You picked %s." % _parts_text(plant.kind.part, plant.stock)
		_pick(plant, rect)
	elif plant != null and plant.rusted and _last_worked:
		plant.rusted = false
		_result = "You scraped off the rust. The %s will grow parts again." % plant.kind.name
		_flash(rect)
	_after_task()


func _on_piece(piece: Piece) -> void:
	for part: String in piece.needs:
		_box[part] -= int(piece.needs[part])
	piece.built = true
	_float("-" + _needs_text(piece), BOX.get_center(), piece.rect.get_center())
	_flash(piece.rect)
	_result = "You built the %s onto the airship." % piece.name
	_after_task()


func _pick(plant: Plant, from: Rect2) -> void:
	if plant.stock == 0:
		return
	_float("+" + _parts_text(plant.kind.part, plant.stock), from.get_center(), BOX.get_center())
	_flash(BOX)
	_box[plant.kind.part] += plant.stock
	plant.stock = 0


func _after_task() -> void:
	if _done_at < 0.0 and _tasks_left() == 0:
		_done_at = BREAK_SECONDS - _break_left
	_refresh()


func _do_every_task() -> void:
	for i: int in SLOTS:
		if _held != null and _garden[i] == null:
			_on_slot(i)
	for i: int in SLOTS:
		var plant: Plant = _garden[i]
		if plant != null:
			_pick(plant, _slot_rect(i))
	for piece: Piece in _pieces:
		if _piece_usable(piece):
			_on_piece(piece)


func _tasks_left() -> int:
	var n := 0
	for i: int in SLOTS:
		if _slot_usable(i):
			n += 1
	for piece: Piece in _pieces:
		if _piece_usable(piece):
			n += 1
	return n


func _slot_usable(i: int) -> bool:
	var plant: Plant = _garden[i]
	return _phase == Phase.BREAK and (
		(_held != null and (plant == null or _garden_full()))
		or (plant != null and ((plant.rusted and _last_worked) or plant.stock > 0))
	)


func _piece_usable(piece: Piece) -> bool:
	if _phase != Phase.BREAK or piece.built:
		return false
	for part: String in piece.needs:
		if int(_box[part]) < int(piece.needs[part]):
			return false
	return true


func _garden_full() -> bool:
	return not _garden.has(null)


func _built_count() -> int:
	var n := 0
	for piece: Piece in _pieces:
		if piece.built:
			n += 1
	return n


func _parts_text(part: String, n: int) -> String:
	var names := {"cog": ["cog", "cogs"], "tubing": ["tube", "tubes"], "plate": ["plate", "plates"]}
	var pair: Array = names[part]
	return "%d %s" % [n, pair[0] if n == 1 else pair[1]]


func _needs_text(piece: Piece) -> String:
	var bits: PackedStringArray = []
	for part: String in piece.needs:
		bits.append(_parts_text(part, int(piece.needs[part])))
	return ", ".join(bits)


func _slot_rect(i: int) -> Rect2:
	var col := i % 3
	var row := floori(i / 3.0)
	return Rect2(PLOT.position + Vector2(6 + col * 104, 6 + row * 56), Vector2(100, 52))


func _clock(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _update_text() -> void:
	_banner.text = _next_step()
	_result_label.text = _result
	var parts: PackedStringArray = [
		"Sessions worked: %d" % _worked,
		"stopped early: %d" % _stopped,
		"airship: %d of %d pieces built" % [_built_count(), _pieces.size()],
	]
	if _phase == Phase.BREAK:
		var took := ""
		if _done_at >= 0.0:
			took = " (your break tasks took %s)" % _clock(_done_at)
		parts.insert(0, "Break: %s left%s" % [_clock(_break_left), took])
	_status.text = "  ·  ".join(parts)


func _refresh() -> void:
	if _log_input:
		print("now: %s | %s" % [_next_step(), _result])
	for child: Node in _dynamic.get_children():
		child.queue_free()
	for i: int in SLOTS:
		_build_slot(i)
	for piece: Piece in _pieces:
		_build_piece(piece)
	_build_arm_and_box()
	_build_bar()
	_update_text()


func _build_slot(i: int) -> void:
	var plant: Plant = _garden[i]
	var text := ""
	if plant != null:
		var state := "growing"
		if plant.rusted:
			state = "rusty"
		elif plant.stock > 0:
			state = "%s ready" % _parts_text(plant.kind.part, plant.stock)
		text = "%s\n%s" % [plant.kind.name, state]
	var b := _button(text, _slot_rect(i), _on_slot.bind(i), _slot_usable(i), true)
	if plant != null:
		var colour := RUST if plant.rusted else plant.kind.colour
		b.add_theme_color_override("font_color", colour)
		b.add_theme_color_override("font_disabled_color", colour.darkened(0.2))


func _build_piece(piece: Piece) -> void:
	var text := piece.name + ("\nbuilt" if piece.built else "\nneeds " + _needs_text(piece))
	var b := _button(text, piece.rect, _on_piece.bind(piece), _piece_usable(piece), true)
	if piece.built:
		b.add_theme_color_override("font_disabled_color", DARK_TEXT)


func _build_arm_and_box() -> void:
	var arm := "Robot arm\nHolding: nothing"
	if _held != null:
		arm = "Robot arm\nHolding: %s %s" % ["a rusty" if _held.rusted else "a new", _held.kind.name]
	_label(ARM.grow(-8), FONT_SMALL, arm, _dynamic)
	var box := "Parts box\n%s\n%s\n%s" % [
		_parts_text("cog", int(_box["cog"])),
		_parts_text("tubing", int(_box["tubing"])),
		_parts_text("plate", int(_box["plate"])),
	]
	_label(BOX.grow(-8), FONT_SMALL, box, _dynamic)


func _build_bar() -> void:
	match _phase:
		Phase.CHOOSE:
			for i: int in _kinds.size():
				var kind := _kinds[i]
				var pick := _button(
					"%s seed\ngrows %s" % [kind.name, _parts_text(kind.part, 2).trim_prefix("2 ")],
					Rect2(16 + i * 152, 666, 146, 50), _choose.bind(kind), true, false
				)
				pick.toggle_mode = true
				pick.set_pressed_no_signal(kind == _chosen)
				if kind == _chosen:
					pick.text += " (chosen)"
					pick.add_theme_color_override("font_pressed_color", BRASS.lightened(0.35))
			var go := _button("Work for 25 minutes  (skipped in this test)", WORK, _work_and_refresh, true, false)
			go.add_theme_color_override("font_color", BRASS.lightened(0.35))
			_button("Stop early", STOP, _stop_and_refresh, true, false)
		Phase.BREAK:
			_button("Back to work", BACK, _back_to_work, true, false)
			if _built_count() == _pieces.size():
				_button("Launch the airship", LAUNCH, _launch, true, false)
		Phase.LAUNCHED:
			_button("Start over", OVER, _start_over, true, false)


func _choose(kind: Kind) -> void:
	_chosen = kind
	_result = "The robot arm will build a %s." % kind.name
	_refresh()


func _work_and_refresh() -> void:
	_work()
	_refresh()


func _stop_and_refresh() -> void:
	_stop_early()
	_refresh()


func _back_to_work() -> void:
	_phase = Phase.CHOOSE
	_result = "Back to work."
	if _held != null:
		_result = "The robot arm keeps holding the %s until your next break." % _held.kind.name
	_refresh()


func _launch() -> void:
	_phase = Phase.LAUNCHED
	_result = "It took %d sessions of work (and %d stopped early)." % [_worked, _stopped]
	_refresh()


func _start_over() -> void:
	get_tree().reload_current_scene()


# Feedback: a brass flash over a rectangle, and words that float from one
# place to another and fade.
func _flash(rect: Rect2) -> void:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = Color(BRASS, 0.7)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(r)
	var t := r.create_tween()
	t.tween_property(r, "modulate:a", 0.0, 0.6)
	t.tween_callback(r.queue_free)


func _float(text: String, from: Vector2, to: Vector2) -> void:
	var l := _label(Rect2(from - Vector2(60, 12), Vector2(120, 24)), 16, text, _fx)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", BRASS.lightened(0.4))
	l.add_theme_color_override("font_outline_color", DARK_TEXT)
	l.add_theme_constant_override("outline_size", 4)
	var t := l.create_tween()
	t.tween_property(l, "position", to - Vector2(60, 12), 0.9).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.7)
	t.tween_callback(l.queue_free)


func _button(text: String, rect: Rect2, action: Callable, enabled: bool, flat: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.flat = flat
	b.disabled = not enabled
	b.clip_text = true
	b.add_theme_font_size_override("font_size", FONT_SMALL)
	b.pressed.connect(action)
	_dynamic.add_child(b)
	return b


func _label(rect: Rect2, font_size: int, text := "", parent: Node = self) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WOOD)
	draw_rect(BANNER, WOOD.darkened(0.35))
	draw_rect(Rect2(0, DOORWAY.end.y, size.x, size.y - DOORWAY.end.y), FLOOR)
	draw_rect(Rect2(DOORWAY.position, Vector2(DOORWAY.size.x, GROUND_TOP - DOORWAY.position.y)), SKY)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(140, 200), Vector2(250, 110), Vector2(330, 165), Vector2(420, 86),
			Vector2(540, 175), Vector2(620, 130), Vector2(620, 200),
		]),
		HILLS,
	)
	draw_rect(Rect2(DOORWAY.position.x, GROUND_TOP, DOORWAY.size.x, DOORWAY.end.y - GROUND_TOP), GRASS)
	draw_rect(DOORWAY, LINE, false, 2.0)
	draw_rect(PLOT, SOIL)
	for board: Rect2 in [GOAL, HOW]:
		draw_rect(board, WOOD.lightened(0.18))
		draw_rect(board, BRASS.darkened(0.2), false, 2.0)
	draw_rect(ARM, WOOD.lightened(0.12))
	draw_rect(BOX, WOOD.lightened(0.12))
	var glow := Color(BRASS, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006))
	for i: int in SLOTS:
		var rect := _slot_rect(i)
		var plant: Plant = _garden[i]
		if plant != null:
			draw_circle(rect.position + Vector2(12, 12), 6.0, RUST if plant.rusted else plant.kind.colour)
		if _slot_usable(i):
			draw_rect(rect, glow, false, 3.0)
		else:
			draw_rect(rect, LINE.darkened(0.5), false, 1.0)
	for piece: Piece in _pieces:
		if piece.built:
			draw_rect(piece.rect, BRASS)
		elif _piece_usable(piece):
			draw_rect(piece.rect, glow, false, 3.0)
		else:
			draw_rect(piece.rect, LINE.darkened(0.55), false, 1.0)
	match _phase:
		Phase.CHOOSE:
			draw_rect(WORK.grow(3), glow, false, 3.0)
		Phase.BREAK:
			if _built_count() == _pieces.size():
				draw_rect(LAUNCH.grow(3), glow, false, 3.0)
			elif _tasks_left() == 0:
				draw_rect(BACK.grow(3), glow, false, 3.0)
		Phase.LAUNCHED:
			draw_rect(OVER.grow(3), glow, false, 3.0)

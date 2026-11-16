extends SceneTree
## Writes a garden at a stage of the game, for trying Airship out (bin/try):
## it plays real sessions through the core, breaks and all, so the garden is
## one the game itself could have made.
##
## Run it: godot --headless --path . --script res://tools/try_garden.gd -- <stage> <garden.json>

const STAGES: Array[String] = ["new", "train", "trade", "pennant", "launch", "valley"]

# Whether the stage asked for was reached.
var _there := true


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in STAGES:
		printerr("try_garden: give a stage (%s) and a garden file" % ", ".join(STAGES))
		quit(1)
		return
	if not args[1].ends_with(".json"):
		printerr("try_garden: the garden file must be a .json: %s" % args[1])
		quit(1)
		return
	DirAccess.remove_absolute(args[1])
	var options := Options.new()
	options.garden_path = args[1]
	var app := App.new(options)
	match args[0]:
		"train":
			# One session short of the night train and the first commission.
			_play(app, func() -> bool: return Parts.sessions(app.garden.valley_plants()) >= 4)
		"trade":
			# The train stands at the station, its trade the next thing asked.
			_play(app, func() -> bool: return app.break_step() == App.BreakStep.TRADE)
		"pennant":
			_play(app, func() -> bool: return app.commissions().met >= 2, true)
		"launch":
			_play(app, func() -> bool: return app.break_step() == App.BreakStep.LAUNCH)
		"valley":
			_play(app, func() -> bool: return app.break_step() == App.BreakStep.LAUNCH)
			app.take_break_step()
			_there = _there and app.garden.valley() == 1
	if not _there:
		printerr("try_garden: the game didn't reach the stage %s" % args[0])
		quit(1)
		return
	if app.garden.problem() != Garden.Problem.NONE or (args[0] != "new" and not FileAccess.file_exists(args[1])):
		printerr("try_garden: the garden couldn't be written to %s" % args[1])
		quit(1)
		return
	quit()


## Completes sessions, taking each break's steps (but never the trade or
## the launch), until `there` says the stage is reached; `for_commissions`
## builds what the visiting airships ask for.
func _play(app: App, there: Callable, for_commissions := false) -> void:
	var sessions := 0
	while not there.call() and sessions < 80:
		# What the airship needs; or, for pennants, what the commission
		# asks for when one is open.
		var blueprint := app.blueprint()
		var asked := app.commissions().open
		if for_commissions and asked != null and asked.kind in Parts.unlocked(app.airship_progress()):
			blueprint = asked.kind
		sessions += 1
		app.start(blueprint, sessions * 7919 + 13)
		app.advance(app.session.seconds() * 1000)
		while not there.call() and app.break_step() not in [App.BreakStep.NONE, App.BreakStep.TRADE, App.BreakStep.LAUNCH]:
			app.take_break_step()
	_there = there.call() as bool

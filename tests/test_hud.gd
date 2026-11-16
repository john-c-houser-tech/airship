extends TestCase
## The help banner: what it lists for where the game stands.

const Hud := preload("res://scene/hud.gd")


func _keys(hud: Hud) -> Array[String]:
	var keys: Array[String] = []
	for entry: Hud.Entry in hud.banner_entries():
		if not entry.key.is_empty():
			keys.append(entry.key)
	return keys


func _hud(state: Session.State, step := App.BreakStep.NONE) -> Hud:
	var hud := Hud.new()
	hud.state = state
	hud.break_step = step
	return hud


func test_the_banner_lists_only_the_keys_that_do_something_now() -> void:
	var idle := _hud(Session.State.IDLE)
	same(_keys(idle), ["Space", "Left, Right", "M", "H"] as Array[String], "between sessions")
	idle.free()
	var building := _hud(Session.State.BUILDING, App.BreakStep.TRADE)
	building.remaining = 65
	same(_keys(building), ["Space", "M", "H"] as Array[String], "while the arm builds, whatever the break held")
	same(building.banner_entries()[0].text, "1:05", "with the time left at its head")
	building.free()
	var planting := _hud(Session.State.BUILT, App.BreakStep.PLANT)
	same(_keys(planting), ["Space", "Left, Right", "Enter key", "M", "H"] as Array[String], "a step of the break: Enter")
	planting.free()
	var trading := _hud(Session.State.BUILT, App.BreakStep.TRADE)
	same(_keys(trading), ["Space", "Left, Right", "T", "M", "H"] as Array[String], "the train's offer: T, not Enter")
	trading.free()
	var finished := _hud(Session.State.BUILT, App.BreakStep.LAUNCH)
	same(_keys(finished), ["Space", "Left, Right", "L", "M", "H"] as Array[String], "a finished airship: L, not Enter")
	finished.free()


func test_the_banner_says_what_each_key_does_now() -> void:
	var hud := _hud(Session.State.IDLE)
	var does := {}
	for entry: Hud.Entry in hud.banner_entries():
		does[entry.key] = entry.text
	same(does["Space"], "start 25 minutes of focus", "Space starts")
	same(does["M"], "turn the sounds off", "M turns the sounds off")
	hud.state = Session.State.BUILDING
	hud.muted = true
	does.clear()
	var said: Array[String] = []
	for entry: Hud.Entry in hud.banner_entries():
		does[entry.key] = entry.text
		said.append(entry.text)
	same(does["Space"], "give up this session", "Space gives up while building")
	same(does["M"], "turn the sounds on", "M turns them on again")
	check("Sounds are off. Press M to turn them on." in said, "and the banner says they are off")
	hud.free()

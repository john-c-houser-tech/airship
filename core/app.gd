class_name App
extends RefCounted
## Airship's state and the rules that tie its parts together. The window
## calls in (a key pressed, time passed) and hears back a list of events
## saying what changed; App itself runs no timers and draws nothing.
##
## It grows with milestone 4: the garden, the light and weather, languages
## and sounds join it in later PRs.

## Something that changed, for the window to hear about.
enum Event {
	## A session started, finished or was given up.
	STATE,
	## The countdown moved on a second, or the plant grew enough to show.
	PROGRESS,
}

var options: Options
var session: Session


func _init(options_: Options) -> void:
	options = options_
	session = Session.new(options.seconds)


## Starts building the plant of `blueprint` and `plant_seed`, unless a
## session is under way.
func start(blueprint: int, plant_seed: int) -> Array[int]:
	return _session_changed(session.start(blueprint, plant_seed))


## Giving up early leaves the half-built plant to rust.
func give_up() -> Array[int]:
	return _session_changed(session.give_up())


## Moves the clock on by real time that has passed.
func advance(milliseconds: int) -> Array[int]:
	return _session_changed(session.advance(milliseconds))


func _session_changed(changes: Session.Changes) -> Array[int]:
	var events: Array[int] = []
	if changes.state:
		events.append(Event.STATE)
	if changes.progress:
		events.append(Event.PROGRESS)
	return events

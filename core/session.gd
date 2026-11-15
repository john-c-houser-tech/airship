class_name Session
extends RefCounted
## One focus session at a time. The arm builds a plant from a blueprint (its
## kind: core/parts.gd; the scene draws every kind alike until milestone 6b);
## the plant on screen is a pure function of `progress`, `blueprint` and `seed`,
## so everything the window shows about the session comes from here. Nothing
## in core/ draws or runs timers: the window passes in the time that passed.
##
## Grove's session.rs is the spec; its growing plant became the arm's build,
## and its wilted plant became a rusted one.

## Seeds are drawn from 1 up to this, 2^30.
const SEED_LIMIT := 0x4000_0000

## Where a session stands. A session given up leaves its half-built plant
## seized with rust; a later session can bring it back.
enum State { IDLE, BUILDING, BUILT, RUSTED }


## What a call changed that the window should hear about.
class Changes:
	## A session started, finished or was given up.
	var state := false
	## The countdown moved on a second, or the plant grew enough to show
	## (0.2% of a session); not on every tick, which no one could see.
	var progress := false


var _seconds: int
var _state := State.IDLE
var _elapsed_ms := 0
var _progress := 0.0
# What the window was last told, so ticks too small to see go unannounced.
var _shown_remaining := 0
var _shown_progress := 0.0
var _blueprint := 0
var _seed := 1


## `seconds` is the session's length; tests and AIRSHIP_SECONDS shorten it.
func _init(seconds: int) -> void:
	_seconds = maxi(seconds, 1)


func state() -> State:
	return _state


## How far through the session, from 0 to 1.
func progress() -> float:
	return _progress


## Whole seconds left, rounded up, so the countdown never shows 0 early.
func remaining() -> int:
	var left := maxi(_total_ms() - _elapsed_ms, 0)
	return ceili(left / 1000.0)


## How long the session has run, in seconds.
func elapsed_seconds() -> float:
	return _elapsed_ms / 1000.0


## The session's full length.
func seconds() -> int:
	return _seconds


## The blueprint the arm is building.
func blueprint() -> int:
	return _blueprint


## The plant's seed, new each session, so no two plants are alike.
func plant_seed() -> int:
	return _seed


## Starts building the plant of `blueprint` and `seed`, unless a session is
## already under way.
func start(blueprint_: int, seed_: int) -> Changes:
	var changes := Changes.new()
	if _state == State.BUILDING:
		return changes
	_elapsed_ms = 0
	_progress = 0.0
	_blueprint = blueprint_
	_seed = seed_
	_shown_remaining = remaining()
	_shown_progress = 0.0
	_state = State.BUILDING
	changes.state = true
	changes.progress = true
	return changes


## Giving up early leaves the half-built plant to rust.
func give_up() -> Changes:
	var changes := Changes.new()
	if _state != State.BUILDING:
		return changes
	_state = State.RUSTED
	changes.state = true
	return changes


## Moves the session clock on by real time that has passed.
func advance(milliseconds: int) -> Changes:
	var changes := Changes.new()
	if _state != State.BUILDING:
		return changes
	_elapsed_ms += maxi(milliseconds, 0)
	var total := _total_ms()
	_progress = minf(float(_elapsed_ms) / total, 1.0)
	# A tick moves the build on by a thirty-thousandth of a session, far too
	# little to see, and every listener would redraw for it. So the window
	# hears only when the countdown moves on a second or the plant has grown
	# enough to show, which in a short test session is still many times a
	# second.
	var left := remaining()
	if left != _shown_remaining or _progress - _shown_progress >= 0.002 or _elapsed_ms >= total:
		_shown_remaining = left
		_shown_progress = _progress
		changes.progress = true
	if _elapsed_ms >= total:
		_state = State.BUILT
		changes.state = true
	return changes


func _total_ms() -> int:
	return _seconds * 1000

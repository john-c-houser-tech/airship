class_name Random
extends RefCounted
## Airship's own random numbers: xorshift32, shifts and XORs only, so the same
## seed gives the same numbers on every machine and every Godot version (and
## nothing can overflow). Good enough to roll the weather; not for anything
## that must be unpredictable.

var _state := 0


func _init(seed_value: int) -> void:
	_state = seed_value & 0xFFFF_FFFF
	if _state == 0:
		_state = 0x9E37_79B9
	# Neighbouring seeds start out alike; a few rounds spread them apart.
	for k in 8:
		next()


## The next whole number, from 0 up to 2^32 - 1.
func next() -> int:
	_state ^= (_state << 13) & 0xFFFF_FFFF
	_state ^= _state >> 17
	_state ^= (_state << 5) & 0xFFFF_FFFF
	return _state


## A number from 0 up to (not including) 1.
func unit() -> float:
	return (next() >> 8) / 16777216.0

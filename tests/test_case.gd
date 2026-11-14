class_name TestCase
extends RefCounted
## What every test script extends: checks that note a failure and carry on,
## so one run reports every broken check.

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


## Equal and of the same type: 8.0 is not 8, and "1" is not 1.
func same(actual: Variant, expected: Variant, what: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: got %s, expected %s" % [what, str(actual), str(expected)])

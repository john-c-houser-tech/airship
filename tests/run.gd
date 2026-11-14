extends SceneTree
## Runs every test: each tests/test_*.gd script extends TestCase, and each of
## its methods named test_* is one test, run on a fresh instance. Prints each
## failure and a count, and exits 1 if anything failed.
##
## A test fails if a check in it fails, or if Godot reports an error while it
## runs (a call on null, a bad operand): such an error stops the test early,
## so its checks alone can't be trusted. A test file that doesn't load, or
## doesn't extend TestCase, fails as a whole.
##
## Run it: godot --headless --path . --script res://tests/run.gd
## (bin/test runs it; import the project first so class names resolve.)


## Counts the errors Godot reports, so a test that hits one fails.
class ErrorCounter:
	extends Logger

	var count := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		count += 1
		_lock.unlock()

	func errors() -> int:
		_lock.lock()
		var n := count
		_lock.unlock()
		return n


var _ran := 0
var _failed := 0


func _init() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file: String in files:
		if file.begins_with("test_") and file.ends_with(".gd"):
			_run_file(file, counter)
	OS.remove_logger(counter)
	print("tests: %d run, %d failed" % [_ran, _failed])
	quit(1 if _failed > 0 or _ran == 0 else 0)


func _run_file(file: String, counter: ErrorCounter) -> void:
	var script := load("res://tests/" + file) as GDScript
	if script == null or not script.can_instantiate():
		_fail(file, "(the file)", "it doesn't load")
		return
	for method: Dictionary in script.get_script_method_list():
		var name := method["name"] as String
		if not name.begins_with("test_"):
			continue
		_ran += 1
		var case := script.new() as TestCase
		if case == null:
			_fail(file, name, "the script doesn't extend TestCase")
			continue
		var before := counter.errors()
		case.call(name)
		if counter.errors() > before:
			case.failures.append("Godot reported an error (above) while it ran")
		if not case.failures.is_empty():
			for failure: String in case.failures:
				print("FAIL %s %s: %s" % [file, name, failure])
			_failed += 1


func _fail(file: String, name: String, why: String) -> void:
	print("FAIL %s %s: %s" % [file, name, why])
	_failed += 1
	if name == "(the file)":
		_ran += 1

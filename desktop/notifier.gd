class_name Notifier
extends RefCounted
## The one notification Airship sends: a session's end, through notify-send.
## Part of the one small Omarchy layer. Sent without waiting, so a slow
## notification daemon never holds up the window.

## Whether notices can be sent: false if notify-send isn't on the PATH.
## (Godot starts a missing program without complaint, so it's looked for.)
var working := true

var _program := ""
var _running: Array[int] = []


func _init(path := OS.get_environment("PATH")) -> void:
	_program = find_on_path("notify-send", path)
	working = not _program.is_empty()


## Tells the desktop. Returns whether notify-send could be started.
func send(summary: String, body: String) -> bool:
	# Notices sent earlier have finished by now: asking reaps them.
	_running = _running.filter(func(pid: int) -> bool: return OS.is_process_running(pid))
	if not working:
		return false
	var pid := OS.create_process(_program, arguments(summary, body))
	working = pid > 0
	if working:
		_running.append(pid)
	return working


## What notify-send is run with.
static func arguments(summary: String, body: String) -> PackedStringArray:
	return PackedStringArray(["--app-name=Airship", "--", summary, body])


## The program's full path in one of PATH's folders, or "".
static func find_on_path(program: String, path: String) -> String:
	for folder: String in path.split(":", false):
		var candidate := folder.path_join(program)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

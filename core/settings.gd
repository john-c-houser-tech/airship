class_name Settings
extends RefCounted
## What Airship remembers between runs: whether the sounds are muted. Kept in
## ~/.config/airship/settings.cfg, as plain lines:
##
## [sound]
## muted=true
##
## Grove's settings.rs is the spec. Anything else in the file is kept, line
## for line; a choice that can't be written lasts for this run only, which
## isn't worth troubling anyone over.


## Whether the file says the sounds are muted. No file, or one that doesn't
## say (or can't be read), means they aren't.
static func muted(file: String) -> bool:
	var found: Variant = _plain_text(file)
	var text := found as String if found is String else ""
	var in_sound := false
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("["):
			in_sound = line == "[sound]"
		elif in_sound and line.begins_with("muted="):
			return line.trim_prefix("muted=").strip_edges() == "true"
	return false


## Writes whether the sounds are muted, keeping every other line of the file
## as it was. Read line by line, as Grove did (Godot's own settings reader
## complains aloud about a file it can't parse). A file that can't be read,
## or isn't plain text, is left alone: rewriting it would lose what's in it.
static func remember_muted(file: String, value: bool) -> void:
	if file.is_empty():
		return
	var found: Variant = _plain_text(file)
	if found == null:
		return
	var old := found as String
	var entry := "muted=%s" % ("true" if value else "false")
	var lines: Array[String] = []
	var in_sound := false
	var written := false
	var heading := -1
	for raw: String in old.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("["):
			in_sound = line == "[sound]"
			if in_sound and heading < 0:
				heading = lines.size()
		elif in_sound and line.begins_with("muted="):
			if not written:
				lines.append(entry)
				written = true
			continue
		lines.append(raw.trim_suffix("\r"))
	while not lines.is_empty() and lines.back().is_empty():
		lines.pop_back()
	if not written:
		# Under [sound], which is made if it isn't there.
		if heading < 0:
			if not lines.is_empty():
				lines.append("")
			lines.append("[sound]")
			heading = lines.size() - 1
		lines.insert(heading + 1, entry)
	_write("\n".join(lines) + "\n", file)


## The file as text, "" if there is none, or null if it can't be opened or
## holds anything but plain ASCII text (so it isn't written over).
static func _plain_text(file: String) -> Variant:
	if file.is_empty() or not FileAccess.file_exists(file):
		return ""
	var opened := FileAccess.open(file, FileAccess.READ)
	if opened == null or opened.get_length() > 64 * 1024:
		return null
	var bytes := opened.get_buffer(opened.get_length())
	opened.close()
	for b: int in bytes:
		if b == 0 or b > 127:
			return null
	return bytes.get_string_from_ascii()


## Writes beside the file (the file a link points at, so a link kept with
## dotfiles stays a link), with its permissions, reads it back and renames
## it into place, as the garden is saved: a crash never leaves half a file.
static func _write(text: String, file: String) -> void:
	var target := Garden._resolve_links(file)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var beside := "%s.%d.tmp" % [target, OS.get_process_id()]
	var out := FileAccess.open(beside, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(text)
	out.close()
	var ok := FileAccess.get_file_as_string(beside) == text
	if ok and FileAccess.file_exists(target):
		ok = FileAccess.set_unix_permissions(beside, FileAccess.get_unix_permissions(target)) == OK
	if not ok or DirAccess.rename_absolute(beside, target) != OK:
		DirAccess.remove_absolute(beside)

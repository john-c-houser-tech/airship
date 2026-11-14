class_name DesktopTheme
extends RefCounted
## The desktop's accent colour, from the current Omarchy theme. Part of the
## one small Omarchy layer: the window checks it every couple of seconds and
## hands the colour to the core. Grove's theme.rs is the spec; its corner
## radius from Hyprland waits for the scene that has corners to round.

## Omarchy's default yellow, for when no theme gives an accent.
const DEFAULT_ACCENT := Color("#ffd60a")

## A theme's colours are a few lines; anything bigger isn't one.
const MOST_BYTES := 64 * 1024

var accent := DEFAULT_ACCENT
var _directory := ""
# The file's time and size when last read, so an unchanged file isn't read
# again (times are whole seconds, so the size helps tell a quick edit).
var _read_as := Vector2i(-1, -1)


## The theme in `directory` (Omarchy's current-theme folder), read now; an
## empty directory means none to follow.
func _init(directory: String) -> void:
	_directory = directory
	reload()


## Reads the accent again if the theme changed. Returns whether it changed.
func reload() -> bool:
	if _directory.is_empty():
		return false
	var path := _directory.path_join("theme/colors.toml")
	if not FileAccess.file_exists(path):
		# Omarchy switches themes by removing the old folder and moving the
		# new one in: missing for a moment, so keep the accent until it's back.
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var seen := Vector2i(FileAccess.get_modified_time(path), file.get_length())
	if seen == _read_as:
		return false
	_read_as = seen
	var found := DEFAULT_ACCENT
	if file.get_length() <= MOST_BYTES:
		# As plain bytes: the accent's line is ASCII, and a file that isn't
		# text shouldn't make Godot complain every two seconds.
		var bytes := file.get_buffer(file.get_length())
		for k in bytes.size():
			if bytes[k] == 0:
				bytes[k] = 32
		var hex := accent_in(bytes.get_string_from_ascii())
		if not hex.is_empty():
			found = Color(hex)
	file.close()
	var changed := found != accent
	accent = found
	return changed


## The accent in a theme's colors.toml: the first line of the form
## `accent = "#rrggbb"`, in either kind of quote, or "".
static func accent_in(colors: String) -> String:
	for raw: String in colors.split("\n"):
		var line := raw.strip_edges(true, false)
		if not line.begins_with("accent"):
			continue
		var rest := line.trim_prefix("accent").strip_edges(true, false)
		if not rest.begins_with("="):
			continue
		var value := rest.trim_prefix("=").strip_edges(true, false)
		if value.length() < 9:
			continue
		var quote := value[0]
		if not (quote == "\"" or quote == "'") or value[8] != quote or value[1] != "#":
			continue
		var hex := value.substr(2, 6)
		if hex.is_valid_hex_number(false):
			return "#" + hex
	return ""

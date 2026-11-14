class_name DesktopLanguage
extends RefCounted
## The language picked under Omarchy's Setup > Language: the first line of
## ~/.config/omarchy/language. Part of the one small Omarchy layer: the window
## checks it every couple of seconds, as it does the theme.

## The language code: "en" if there is no file or it says nothing usable.
var code := "en"
var _file := ""


func _init(file: String) -> void:
	_file = file
	reload()


## Reads the code again (the file is a few bytes, so it's simply read each
## time). Returns whether the code changed.
func reload() -> bool:
	var found := "en"
	if not _file.is_empty() and FileAccess.file_exists(_file):
		var file := FileAccess.open(_file, FileAccess.READ)
		if file == null:
			return false
		# Only the first line matters, and only as ASCII.
		var text := file.get_buffer(mini(file.get_length(), 256)).get_string_from_ascii()
		file.close()
		if text.strip_edges().is_empty():
			# omarchy-language rewrites the file in place: caught between
			# emptying it and writing the new code, keep the language.
			return false
		found = Catalog.code_in(text)
	var changed := found != code
	code = found
	return changed

extends TestCase
## Languages, from Grove's language.rs tests, and checks that keep the
## catalogs whole: every string the code says is translated in every
## language, and no catalog keeps a string the code no longer says.

const LANGUAGES: Array[String] = ["da", "de", "es-MX", "fr", "ja", "pt-BR"]
# Calls that pass something other than a written-out string, each checked
# some other way: the garden's reasons are Garden.REASONS, and say() is the
# app's own way in to the catalog.
const PASSED_ON: Array[String] = ["catalog.translate(save_error)", "catalog.translate(source)"]
# Folders that aren't Airship's own code.
const NOT_SCANNED: Array[String] = ["res://tests", "res://prototypes", "res://.godot", "res://build", "res://i18n"]


func _folder(name: String, files: Dictionary) -> String:
	var folder := OS.get_user_data_dir().path_join("catalog-tests").path_join(name)
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in files:
		var out := FileAccess.open(folder.path_join(file), FileAccess.WRITE)
		out.store_string(files[file] as String)
		out.close()
	return folder


## Every English string the code asks for by name, in every script of
## Airship's own (comments left out), and anything it passes to be translated
## that the scan can't read: those must be in PASSED_ON.
func _said_in_code() -> Array[String]:
	var found: Array[String] = []
	found.append_array(Garden.REASONS)
	var literal := RegEx.create_from_string("(?:translate|say)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*\\)")
	var any_call := RegEx.create_from_string("[\\w.]*(?:translate|say)\\([^\\n]*")
	for path: String in _scripts("res://"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("func "):
				continue
			var written := literal.search_all(code)
			for hit: RegExMatch in written:
				var text := hit.get_string(1).c_unescape()
				if not text in found:
					found.append(text)
			for call: RegExMatch in any_call.search_all(code):
				var plain := false
				for hit: RegExMatch in written:
					plain = plain or call.get_string().contains(hit.get_string())
				var passed := false
				for allowed: String in PASSED_ON:
					passed = passed or call.get_string().begins_with(allowed)
				check(plain or passed, "%s passes something the check can't read: %s" % [path, code])
	return found


func _scripts(folder: String) -> Array[String]:
	var paths: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			paths.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub)
		if not path in NOT_SCANNED and not sub.begins_with("."):
			paths.append_array(_scripts(path))
	return paths


func test_every_string_on_screen_is_translated_in_every_language() -> void:
	var said := _said_in_code()
	check(said.size() >= 15, "found what the code says (%d strings)" % said.size())
	check("Built" in said and Garden.NOT_WHOLE in said, "including the notice and the garden's reasons")
	for code: String in LANGUAGES:
		var catalog := Catalog.new(code)
		for text: String in said:
			check(catalog.translate(text) != text, "%s has no translation of: %s" % [code, text])


func test_no_catalog_keeps_strings_the_code_no_longer_says() -> void:
	var said := _said_in_code()
	for code: String in LANGUAGES:
		var json := JSON.new()
		same(json.parse(FileAccess.get_file_as_string("res://i18n/%s.json" % code)), OK, code + " parses")
		for source: String in json.data as Dictionary:
			check(source in said, "%s keeps a string nothing says: %s" % [code, source])
			check(source.count("%s") == ((json.data as Dictionary)[source] as String).count("%s"),
				"%s keeps the %%s in: %s" % [code, source])


func test_a_missing_string_falls_back_toward_english_a_step_at_a_time() -> void:
	var folder := _folder("fallback", {
		"en.json": "{}",
		"pt.json": "{\"Built\": \"Construída (pt)\", \"Quit\": \"Sair (pt)\"}",
		"pt-BR.json": "{\"Built\": \"Construída\", \"Empty\": \"\"}",
	})
	var catalog := Catalog.new("pt-BR", folder)
	same(catalog.translate("Built"), "Construída", "the regional file first")
	same(catalog.translate("Quit"), "Sair (pt)", "then the base language")
	same(catalog.translate("Empty"), "Empty", "an empty translation is no translation")
	same(catalog.translate("Unknown"), "Unknown", "then the English")


func test_a_broken_catalog_is_passed_over() -> void:
	var folder := _folder("broken", {"en.json": "{}", "de.json": "not json"})
	same(Catalog.new("de", folder).translate("Built"), "Built", "English")


func test_reads_omarchys_language_codes() -> void:
	same(Catalog.code_in("de\n"), "de", "a language")
	same(Catalog.code_in("pt-BR"), "pt-BR", "with a region")
	same(Catalog.code_in("  es-MX  \nsecond line"), "es-MX", "the first line, trimmed")
	for bad: String in ["", "German", "DE", "d", "pt-BRA", "pt_BR", "de-1A", "../../etc"]:
		same(Catalog.code_in(bad), "en", "English for " + bad)


func test_follows_omarchys_language_file() -> void:
	var folder := _folder("language-file", {"language": "fr\n"})
	var path := folder.path_join("language")
	var desktop := DesktopLanguage.new(path)
	same(desktop.code, "fr", "read at once")
	check(not desktop.reload(), "unchanged")
	# omarchy-language empties the file, then writes the new code into it.
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.close()
	check(not desktop.reload(), "caught while omarchy-language rewrites it")
	same(desktop.code, "fr", "keeps the language meanwhile, never a flash of English")
	out = FileAccess.open(path, FileAccess.WRITE)
	out.store_string("ja\n")
	out.close()
	check(desktop.reload(), "a new language is noticed")
	same(desktop.code, "ja", "the new language")
	DirAccess.remove_absolute(path)
	check(desktop.reload(), "a file that's gone")
	same(desktop.code, "en", "is English, as in Grove")
	same(DesktopLanguage.new("").code, "en", "no file, English")


func test_the_app_speaks_the_desktops_language_unless_pinned() -> void:
	var app := App.new(Options.new())
	same(app.say("Built"), "Built", "English to start")
	same(app.set_language("de"), [App.Event.LANGUAGE] as Array[int], "a new language")
	same(app.say("Built"), "Gebaut", "German")
	same(app.set_language("de"), [] as Array[int], "the same language again")
	var options := Options.new()
	options.language = "ja"
	var pinned := App.new(options)
	same(pinned.set_language("de"), [] as Array[int], "AIRSHIP_LANGUAGE wins")
	same(pinned.say("Built"), "完成", "Japanese")

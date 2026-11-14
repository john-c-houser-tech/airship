class_name Catalog
extends RefCounted
## The words of one language. Catalogs are flat JSON objects from the English
## to the translation, one per Omarchy language code (i18n/de.json,
## i18n/pt-BR.json), so the code keeps the English and asks for it by name.
##
## Grove's language.rs is the spec. Its plural forms for counted strings wait
## until Airship has a counted string to show.

const FOLDER := "res://i18n"

var _code := "en"
var _strings := {}


## The strings for a language code: English first, then the base language,
## then the regional file over it (pt, then pt-BR), so a missing string falls
## back toward English one step at a time. `folder` is for tests.
func _init(code: String, folder := FOLDER) -> void:
	_code = code
	var codes: Array[String] = ["en"]
	for next: String in [code.get_slice("-", 0), code]:
		if not next in codes:
			codes.append(next)
	for each: String in codes:
		var path := folder.path_join(each + ".json")
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
			continue
		for source: Variant in json.data as Dictionary:
			var translation: Variant = (json.data as Dictionary)[source]
			if translation is String and not (translation as String).is_empty():
				_strings[source] = translation


## The Omarchy language code ("en", "pt-BR").
func code() -> String:
	return _code


## The translation of an English text, or the English if there is none.
func translate(source: String) -> String:
	return _strings.get(source, source) as String


## The language code on the first line of Omarchy's language file; anything
## that isn't a language code is English.
static func code_in(text: String) -> String:
	var code := text.get_slice("\n", 0).strip_edges()
	var parts := code.split("-")
	var language := parts[0]
	var valid := parts.size() <= 2 and language.length() >= 2 and language.length() <= 3 \
		and language == language.to_lower() and _letters(language)
	if valid and parts.size() == 2:
		valid = parts[1].length() == 2 and _letters(parts[1])
	return code if valid else "en"


static func _letters(text: String) -> bool:
	for k in text.length():
		var c := text.unicode_at(k)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
			return false
	return true

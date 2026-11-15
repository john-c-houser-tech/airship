extends TestCase
## Reading the test knobs and the desktop's folders, from Grove's options.rs
## tests.


func _from(variables: Dictionary) -> Options:
	return Options.from_variables(func(name: String) -> String: return variables.get(name, "") as String)


func test_defaults_without_variables() -> void:
	var options := _from({})
	same(options.seconds, 25 * 60, "seconds")
	same(options.time_minutes, -1, "time")
	check(options.date.is_empty(), "no date")
	same(options.weather, "", "weather")
	same(options.garden_path, "", "garden")
	same(options.data_directory, "", "data directory")


func test_reads_every_knob() -> void:
	var options := _from({
		"AIRSHIP_SECONDS": " 30 ",
		"AIRSHIP_TIME": "17:05",
		"AIRSHIP_DATE": "2026-10-20",
		"AIRSHIP_WEATHER": "Fog",
		"AIRSHIP_GARDEN": "/tmp/garden.json",
	})
	same(options.seconds, 30, "seconds")
	same(options.time_minutes, 17 * 60 + 5, "time")
	same(options.date, {"year": 2026, "month": 10, "day": 20}, "date")
	same(options.weather, "fog", "weather")
	same(options.garden_path, "/tmp/garden.json", "garden")


func test_ignores_values_that_do_not_parse() -> void:
	var options := _from({
		"AIRSHIP_SECONDS": "-4",
		"AIRSHIP_TIME": "25:00",
		"AIRSHIP_DATE": "2026-02-30",
		"AIRSHIP_WEATHER": "hail",
	})
	same(options.seconds, 25 * 60, "seconds")
	same(options.time_minutes, -1, "time")
	check(options.date.is_empty(), "no date")
	same(options.weather, "", "weather")


func test_rejects_half_written_values() -> void:
	var options := _from({"AIRSHIP_SECONDS": "30s", "AIRSHIP_TIME": "17", "AIRSHIP_DATE": "2026-10"})
	same(options.seconds, 25 * 60, "seconds")
	same(options.time_minutes, -1, "time")
	check(options.date.is_empty(), "no date")


func test_data_directory_prefers_xdg() -> void:
	same(_from({"HOME": "/home/a"}).data_directory, "/home/a/.local/share", "from HOME")
	same(_from({"HOME": "/home/a", "XDG_DATA_HOME": "/data"}).data_directory, "/data", "from XDG_DATA_HOME")
	same(_from({"HOME": "/home/a"}).theme_directory, "/home/a/.local/state/omarchy/current", "Omarchy's theme")
	same(_from({}).theme_directory, "", "no theme without HOME")
	same(_from({"HOME": "/home/a"}).language_file, "/home/a/.config/omarchy/language", "Omarchy's language")


func test_a_pinned_language_must_be_a_language_code() -> void:
	same(_from({"AIRSHIP_LANGUAGE": " pt-BR "}).language, "pt-BR", "a code")
	same(_from({"AIRSHIP_LANGUAGE": "Klingon"}).language, "", "anything else follows Omarchy")
	same(_from({}).language, "", "unset follows Omarchy")


func test_knows_leap_years() -> void:
	same(_from({"AIRSHIP_DATE": "2028-02-29"}).date, {"year": 2028, "month": 2, "day": 29}, "a leap day")
	check(_from({"AIRSHIP_DATE": "2026-02-29"}).date.is_empty(), "no leap day in 2026")
	check(_from({"AIRSHIP_DATE": "2100-02-29"}).date.is_empty(), "no leap day in 2100")
	check(_from({"AIRSHIP_DATE": "2026-04-31"}).date.is_empty(), "April has 30 days")


func test_ignores_numbers_too_big_to_be_a_session() -> void:
	same(_from({"AIRSHIP_SECONDS": "10000000000000000"}).seconds, 25 * 60, "a huge length")
	same(_from({"AIRSHIP_SECONDS": "99999999999999999999"}).seconds, 25 * 60, "past 64 bits")
	same(_from({"AIRSHIP_SECONDS": "+30"}).seconds, 25 * 60, "a sign")
	same(_from({"AIRSHIP_SECONDS": "999999999"}).seconds, 999999999, "the longest allowed")

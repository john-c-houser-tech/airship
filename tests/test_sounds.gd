extends TestCase
## The distant sounds: when they happen (from Grove's sounds.rs tests), how
## the app tells the window, mute remembered between runs, and the sounds
## bin/test makes.

const SESSION := 25.0 * 60.0


func _daylight(hour: float) -> Daylight:
	return Daylight.at(172, hour, App.DEFAULT_ACCENT)


func _settings(name: String) -> String:
	var folder := OS.get_user_data_dir().path_join("settings-tests").path_join(name)
	OS.execute("rm", ["-rf", folder])
	return folder.path_join("airship/settings.cfg")


func test_trains_by_night_airships_by_day_nothing_between() -> void:
	same(Sounds.period_of(_daylight(13.0)), Sounds.Period.DAY, "midday")
	same(Sounds.period_of(_daylight(1.0)), Sounds.Period.NIGHT, "the small hours")
	var sunset := Daylight.sun_times(172).y
	same(Sounds.period_of(_daylight(sunset + 0.05)), Sounds.Period.BETWEEN, "just after sunset")
	same(Sounds.roll(Random.new(1), -1, Sounds.Period.BETWEEN, SESSION), null, "nothing at dusk")
	for seed_value in range(1, 30):
		var night := Sounds.roll(Random.new(seed_value), -1, Sounds.Period.NIGHT, SESSION)
		check(night != null and night.kind == Sounds.Kind.TRAIN, "a night always has a train (seed %d)" % seed_value)
		var day := Sounds.roll(Random.new(seed_value), -1, Sounds.Period.DAY, SESSION)
		check(day == null or day.kind == Sounds.Kind.AIRSHIP, "a day has an airship or nothing")


func test_how_many_times() -> void:
	var trains := {}
	var airships := {}
	var random := Random.new(5)
	for k in 2000:
		trains[Sounds.count(Sounds.Kind.TRAIN, random)] = true
		airships[Sounds.count(Sounds.Kind.AIRSHIP, random)] = true
	var counts := trains.keys()
	counts.sort()
	same(counts, [1, 2, 3], "a train comes 1 to 3 times")
	check(airships.has(0) and airships.has(1) and airships.has(2) and airships.size() == 3, "an airship 0 to 2 times")


func test_sounds_fit_inside_the_session_well_apart() -> void:
	var random := Random.new(9)
	for k in 300:
		var wanted := 1 + k % 3
		var found := Sounds.times(random, wanted, SESSION, 44.0)
		same(found.size(), wanted, "three fit in a full session")
		for at: float in found:
			check(at >= 20.0 and at + 44.0 <= SESSION - 20.0, "inside, away from the ends (%f)" % at)
		for n in range(1, found.size()):
			check(found[n] - found[n - 1] >= 44.0 + 90.0, "well apart")


func test_fewer_fit_a_short_session_and_none_a_tiny_one() -> void:
	same(Sounds.times(Random.new(1), 3, 300.0, 44.0).size(), 2, "two fit in five minutes")
	same(Sounds.times(Random.new(1), 3, 200.0, 44.0).size(), 1, "one in three and a bit")
	same(Sounds.times(Random.new(1), 3, 60.0, 44.0).size(), 0, "none in a minute")


func test_a_due_sound_plays_if_the_sky_still_suits_it() -> void:
	var plan := Sounds.Plan.new()
	plan.kind = Sounds.Kind.AIRSHIP
	plan.times = [100.0, 400.0]
	same(plan.due(99.0, Sounds.Period.DAY, true), -1, "not yet")
	same(plan.due(100.5, Sounds.Period.DAY, false), -1, "fog grounds it")
	same(plan.due(101.0, Sounds.Period.DAY, true), -1, "and it's used up")
	same(plan.due(400.0, Sounds.Period.DAY, true), Sounds.Kind.AIRSHIP as int, "the next one flies")


func test_a_sound_asked_for_plays_three_seconds_in_whatever_the_hour() -> void:
	var plan := Sounds.roll(Random.new(1), Sounds.Kind.TRAIN, Sounds.Period.DAY, SESSION)
	same(plan.times, [3.0] as Array[float], "three seconds in")
	same(plan.due(3.0, Sounds.Period.DAY, false), Sounds.Kind.TRAIN as int, "by day, in fog")


func test_the_app_says_when_a_sound_is_due_and_when_they_end() -> void:
	var options := Options.new()
	options.weather = "clear"
	options.sound_test = Sounds.Kind.AIRSHIP
	options.sound_volume = 0.5
	var app := App.new(options)
	app.start(1, 7)
	check(not App.Event.SOUND in app.advance(2000), "not at two seconds")
	check(App.Event.SOUND in app.advance(1000), "due at three")
	same(app.sound, Sounds.Kind.AIRSHIP, "which")
	same(app.volume(app.sound), 0.2, "its volume, scaled")
	check(App.Event.SOUNDS_ENDED in app.give_up(), "giving up ends them")
	check(not App.Event.SOUNDS_ENDED in app.give_up(), "once")


func test_a_session_without_sounds_never_ends_them() -> void:
	var options := Options.new()
	options.weather = "clear"
	options.time_minutes = int(Daylight.sun_times(172).y * 60.0) + 3
	options.date = {"year": 2026, "month": 6, "day": 21}
	var app := App.new(options)
	app.start(1, 7)
	check(not App.Event.SOUNDS_ENDED in app.give_up(), "dusk: nothing to end")


func test_mute_is_remembered_between_runs() -> void:
	var file := _settings("remembered")
	var options := Options.new()
	options.settings_file = file
	var app := App.new(options)
	check(not app.muted, "not muted at first")
	same(app.set_muted(true), [App.Event.MUTED] as Array[int], "muting is news")
	same(app.set_muted(true), [] as Array[int], "muting again isn't")
	check(App.new(options).muted, "still muted next run")
	app.set_muted(false)
	check(not App.new(options).muted, "and unmuted")


func test_the_settings_file_keeps_what_else_is_in_it() -> void:
	var file := _settings("keeps")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string("[window]\nscale=2\n")
	out.close()
	Settings.remember_muted(file, true)
	same(FileAccess.get_file_as_string(file), "[window]\nscale=2\n\n[sound]\nmuted=true\n", "kept, and added")
	check(Settings.muted(file), "reads back")
	Settings.remember_muted(file, false)
	same(FileAccess.get_file_as_string(file), "[window]\nscale=2\n\n[sound]\nmuted=false\n", "changed in place")
	same(DirAccess.get_files_at(file.get_base_dir()), PackedStringArray(["settings.cfg"]), "nothing left beside it")


func test_an_odd_settings_file_is_read_quietly_and_kept() -> void:
	var file := _settings("odd")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string("[sound\nmuted=true\n")
	out.close()
	check(not Settings.muted(file), "a broken heading isn't [sound]")
	Settings.remember_muted(file, true)
	same(FileAccess.get_file_as_string(file), "[sound\nmuted=true\n\n[sound]\nmuted=true\n", "its lines kept, the setting added")


func test_the_sounds_are_made_whole() -> void:
	for kind in 2:
		var path: String = Sounds.FILES[kind]
		check(ResourceLoader.exists(path), "%s is made (bin/make-sounds)" % path)
		if not ResourceLoader.exists(path):
			continue
		var wav := load(path) as AudioStreamWAV
		same(wav.get_length(), Sounds.SECONDS[kind], "%s lasts as long as the plan says" % path)
		same(wav.mix_rate, 22050, "%s rate" % path)


func test_a_settings_file_that_cannot_be_read_is_never_written_over() -> void:
	var file := _settings("locked")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string("[window]\nscale=2\n")
	out.close()
	FileAccess.set_unix_permissions(file, 0)
	Settings.remember_muted(file, true)
	FileAccess.set_unix_permissions(file, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	var text := FileAccess.get_file_as_string(file)
	if text.contains("muted"):
		# Running as root (as CI may), the file could be read after all: then
		# it must have been kept whole.
		same(text, "[window]\nscale=2\n\n[sound]\nmuted=true\n", "kept whole")
	else:
		same(text, "[window]\nscale=2\n", "left as it was")


func test_a_settings_file_that_is_not_plain_text_is_left_alone() -> void:
	var file := _settings("binary")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_buffer(PackedByteArray([0x5b, 0xc3, 0x28, 0x00, 0x0a]))
	out.close()
	check(not Settings.muted(file), "not muted")
	Settings.remember_muted(file, true)
	same(FileAccess.get_file_as_bytes(file), PackedByteArray([0x5b, 0xc3, 0x28, 0x00, 0x0a]), "left as it was")


func test_a_linked_settings_file_stays_a_link_and_keeps_its_permissions() -> void:
	var folder := _settings("link").get_base_dir().get_base_dir()
	DirAccess.make_dir_recursive_absolute(folder.path_join("dotfiles"))
	DirAccess.make_dir_recursive_absolute(folder.path_join("airship"))
	var real := folder.path_join("dotfiles/settings.cfg")
	var out := FileAccess.open(real, FileAccess.WRITE)
	out.store_string("[window]\nscale=2\n")
	out.close()
	FileAccess.set_unix_permissions(real, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	DirAccess.open(folder.path_join("airship")).create_link("../dotfiles/settings.cfg", "settings.cfg")
	var link := folder.path_join("airship/settings.cfg")
	Settings.remember_muted(link, true)
	check(DirAccess.open(folder.path_join("airship")).is_link("settings.cfg"), "still a link")
	check(Settings.muted(real), "the file it points at was written")
	same(FileAccess.get_unix_permissions(real), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER, "permissions kept")


func test_a_heading_with_stray_spaces_is_still_the_sound_section() -> void:
	var file := _settings("spaces")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string("  [sound]  \r\nmuted=false\r\n")
	out.close()
	Settings.remember_muted(file, true)
	same(FileAccess.get_file_as_string(file), "  [sound]  \nmuted=true\n", "one section, changed in place")


## A made sound's samples, -1 to 1, from the WAV file itself (Godot
## compresses what it imports).
func _samples(kind: Sounds.Kind) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(Sounds.FILES[kind])
	# The samples follow the "data" chunk's name and its 4-byte length.
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var first := at + 8
	var out := PackedFloat32Array()
	out.resize((bytes.size() - first) >> 1)
	for k in out.size():
		out[k] = bytes.decode_s16(first + k * 2) / 32768.0
	return out


func _loudness(samples: PackedFloat32Array, from_s: float, to_s: float) -> float:
	var total := 0.0
	var first := int(from_s * 22050.0)
	var last := int(to_s * 22050.0)
	for k in range(first, last):
		total += samples[k] * samples[k]
	return sqrt(total / (last - first))


func _peak(samples: PackedFloat32Array) -> float:
	var top := 0.0
	for v: float in samples:
		top = maxf(top, absf(v))
	return top


func test_the_made_sounds_sound_as_they_should() -> void:
	# From Grove's synth.rs tests, on the files bin/test makes.
	if not ResourceLoader.exists(Sounds.FILES[0]):
		check(false, "the sounds aren't made (bin/make-sounds)")
		return
	var train := _samples(Sounds.Kind.TRAIN)
	var airship := _samples(Sounds.Kind.AIRSHIP)
	for pair: Array in [[train, "train"], [airship, "airship"]]:
		var samples := pair[0] as PackedFloat32Array
		check(_peak(samples) < 0.95, "%s never clips" % pair[1])
		for edge: PackedFloat32Array in [samples.slice(0, 200), samples.slice(samples.size() - 200)]:
			check(_peak(edge) < 0.01, "%s starts and ends without a click" % pair[1])
	check(_loudness(train, 3.0, 5.0) < _loudness(train, 16.0, 18.0) * 0.6, "the far whistle is quieter than the near one")
	check(_loudness(airship, 15.0, 19.0) > _loudness(airship, 1.0, 5.0) * 4.0, "the airship is loudest overhead")
	check(_peak(airship) < _peak(train) * 0.8, "the airship is fainter than the train")
	check(_loudness(airship, 15.0, 19.0) > 0.02, "but loud enough to hear")

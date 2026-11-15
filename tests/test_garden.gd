extends TestCase
## The garden file, from Grove's garden.rs tests. Each test works in its own
## folder under Godot's user data folder (inside build/test when bin/test
## runs it), emptied first.


func _folder(name: String) -> String:
	var folder := OS.get_user_data_dir().path_join("garden-tests").path_join(name)
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


func _plant(plant_seed: int, outcome: Garden.Outcome = Garden.Outcome.BUILT) -> Garden.Plant:
	var plant := Garden.Plant.new()
	plant.blueprint = 3
	plant.plant_seed = plant_seed
	plant.outcome = outcome
	plant.season = "autumn"
	plant.weather = "fog"
	plant.progress = 1.0 if outcome == Garden.Outcome.BUILT else 0.4
	plant.when = "2026-11-14T09:30:00"
	plant.minutes = 25 if outcome == Garden.Outcome.BUILT else 0
	return plant


func _seeds(garden: Garden) -> Array[int]:
	var seeds: Array[int] = []
	for plant: Garden.Plant in garden.plants():
		seeds.append(plant.plant_seed)
	return seeds


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_an_empty_garden_starts_empty_and_writes_nothing() -> void:
	var path := _folder("empty").path_join("garden.json")
	var garden := Garden.new(path)
	same(garden.plants().size(), 0, "plants")
	same(garden.problem(), Garden.Problem.NONE, "problem")
	check(not FileAccess.file_exists(path), "no file until a plant is kept")


func test_recorded_plants_survive_a_restart_newest_first() -> void:
	var path := _folder("restart").path_join("airship/garden.json")
	var garden := Garden.new(path)
	same(garden.record(_plant(1)), Garden.Change.RESET, "first change")
	garden.record(_plant(2, Garden.Outcome.RUSTED))
	garden.record(_plant(3))
	same(_seeds(garden), [3, 2, 1] as Array[int], "seeds in this garden")
	var again := Garden.new(path)
	same(_seeds(again), [3, 2, 1] as Array[int], "seeds after a restart")
	check(again.plants()[1].equals(_plant(2, Garden.Outcome.RUSTED)), "every field survives")
	same(again.problem(), Garden.Problem.NONE, "problem")
	check(not DirAccess.dir_exists_absolute(path + ".lock"), "the lock is let go")


func test_two_airships_open_together_keep_each_others_plants() -> void:
	var path := _folder("two").path_join("garden.json")
	var one := Garden.new(path)
	var two := Garden.new(path)
	one.record(_plant(1))
	two.record(_plant(2))
	one.record(_plant(3))
	same(_seeds(one), [3, 2, 1] as Array[int], "the first sees the second's plant")
	same(_seeds(Garden.new(path)), [3, 2, 1] as Array[int], "the file has all three")
	same(DirAccess.get_files_at(path.get_base_dir()), PackedStringArray(["garden.json"]), "no temporary files left")
	same(DirAccess.get_directories_at(path.get_base_dir()), PackedStringArray(), "no lock left")


func test_a_garden_spoiled_while_open_is_not_saved_over() -> void:
	var path := _folder("spoiled").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	_write(path, "not a garden")
	same(garden.record(_plant(2)), Garden.Change.INSERTED, "change")
	same(garden.problem(), Garden.Problem.CANNOT_READ, "problem")
	same(_text(path), "not a garden", "the file is left as it was")
	same(_seeds(garden), [2, 1] as Array[int], "the plant still shows")
	check(not DirAccess.dir_exists_absolute(path + ".lock"), "the lock is let go")
	# Put right again while Airship runs, it still isn't saved over.
	var fixed := JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(1))]})
	_write(path, fixed)
	garden.record(_plant(3))
	same(_text(path), fixed, "not saved over once spoiled")


func test_a_file_that_is_not_a_garden_is_left_untouched() -> void:
	var path := _folder("unreadable").path_join("garden.json")
	for text: String in ["not json", "[1, 2]", "{\"plants\": 3}"]:
		_write(path, text)
		var garden := Garden.new(path)
		same(garden.problem(), Garden.Problem.CANNOT_READ, "problem for " + text)
		garden.record(_plant(1))
		same(_text(path), text, "the file is left as it was: " + text)


func test_a_garden_with_one_bad_entry_is_not_overwritten() -> void:
	var path := _folder("bad-entry").path_join("garden.json")
	var good := Garden._plant_to(_plant(1))
	# The same file with the entry as it should be reads fine, so each bad
	# value below is what makes the garden unreadable.
	_write(path, JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(2)), good]}))
	same(Garden.new(path).problem(), Garden.Problem.NONE, "the good entry reads")
	for bad: Array in [["seed", 1.5], ["seed", -1], ["seed", "1"], ["progress", 1.2], ["progress", "1"],
			["outcome", "wilted"], ["when", "2026-11-14"], ["when", "2026-02-30T09:30:00"],
			["when", "2026-11-14T09:30:00\n"], ["minutes", "25"], ["blueprint", null]]:
		var entry := good.duplicate()
		if bad[1] == null:
			entry.erase(bad[0])
		else:
			entry[bad[0]] = bad[1]
		var text := JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(2)), entry]})
		_write(path, text)
		var again := Garden.new(path)
		same(again.problem(), Garden.Problem.CANNOT_READ, "problem with %s" % str(bad))
		again.record(_plant(3))
		same(_text(path), text, "the file is left as it was with %s" % str(bad))


func test_a_busy_garden_keeps_the_plant_unsaved() -> void:
	var path := _folder("busy").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	DirAccess.make_dir_absolute(path + ".lock")
	garden.lock_wait_ms = 150
	same(garden.record(_plant(2)), Garden.Change.INSERTED, "change")
	same(garden.problem(), Garden.Problem.BUSY, "problem")
	same(_seeds(garden), [2, 1] as Array[int], "the plant still shows")
	same(_seeds(Garden.new(path)), [1] as Array[int], "the file wasn't touched")
	check(DirAccess.dir_exists_absolute(path + ".lock"), "someone else's lock is left alone")
	# Once the other lets go, saving works again and the problem clears.
	DirAccess.remove_absolute(path + ".lock")
	same(garden.record(_plant(3)), Garden.Change.RESET, "change once free")
	same(garden.problem(), Garden.Problem.NONE, "the problem clears")
	same(_seeds(Garden.new(path)), [3, 2, 1] as Array[int], "saved, with the plant that waited")


func test_a_lock_left_by_a_crash_is_taken_over() -> void:
	var path := _folder("stale").path_join("garden.json")
	DirAccess.make_dir_absolute(path + ".lock")
	OS.execute("touch", ["-d", "5 minutes ago", path + ".lock"])
	var garden := Garden.new(path)
	garden.lock_wait_ms = 150
	same(garden.record(_plant(1)), Garden.Change.RESET, "change")
	same(garden.problem(), Garden.Problem.NONE, "problem")
	same(_seeds(Garden.new(path)), [1] as Array[int], "saved")


func test_a_garden_that_is_a_link_stays_a_link_and_keeps_its_permissions() -> void:
	var folder := _folder("link")
	var real := folder.path_join("kept/garden.json")
	var link := folder.path_join("garden.json")
	Garden.new(real).record(_plant(1))
	FileAccess.set_unix_permissions(real, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	DirAccess.open(folder).create_link("kept/garden.json", "garden.json")
	Garden.new(link).record(_plant(2))
	check(DirAccess.open(folder).is_link("garden.json"), "still a link")
	same(_seeds(Garden.new(real)), [2, 1] as Array[int], "the file it points at was saved")
	same(FileAccess.get_unix_permissions(real), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER, "permissions")


func test_the_garden_is_kept_in_the_data_folder() -> void:
	same(Garden.default_path("/home/a/.local/share"), "/home/a/.local/share/airship/garden.json", "path")
	same(Garden.default_path(""), "", "nowhere")


func test_a_garden_kept_nowhere_shows_its_plants_and_saves_none() -> void:
	var garden := Garden.new("")
	same(garden.record(_plant(1)), Garden.Change.INSERTED, "change")
	same(garden.problem(), Garden.Problem.NO_FOLDER, "problem")
	same(_seeds(garden), [1] as Array[int], "the plant still shows")


func test_a_folder_that_cannot_be_made_keeps_the_plant_unsaved() -> void:
	var folder := _folder("no-folder")
	_write(folder.path_join("in-the-way"), "a file, not a folder")
	var garden := Garden.new(folder.path_join("in-the-way/garden.json"))
	same(garden.record(_plant(1)), Garden.Change.INSERTED, "change")
	same(garden.problem(), Garden.Problem.NO_FOLDER, "problem")


func test_counts_built_rusted_and_minutes() -> void:
	var garden := Garden.new("")
	garden.record(_plant(1))
	garden.record(_plant(2, Garden.Outcome.RUSTED))
	garden.record(_plant(3))
	same(garden.built(), 2, "built")
	same(garden.rusted(), 1, "rusted")
	same(garden.focused_minutes(), 50, "a rusted plant earns no minutes")


func test_the_file_is_versioned_and_oldest_first() -> void:
	var path := _folder("format").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	garden.record(_plant(2))
	var data: Dictionary = JSON.parse_string(_text(path))
	same(data["version"], 1.0, "version")
	same((data["plants"] as Array)[0]["seed"], 1.0, "oldest first")
	same((data["plants"] as Array)[1]["outcome"], "built", "outcome by name")


func test_a_garden_that_was_unreadable_stays_unsaved_after_it_is_fixed() -> void:
	# Read-only from the moment it couldn't be read: even if the file is
	# put right while Airship runs, it isn't saved over until a restart.
	var path := _folder("stays-read-only").path_join("garden.json")
	_write(path, "not json")
	var garden := Garden.new(path)
	var fixed := JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(1))]})
	_write(path, fixed)
	same(garden.record(_plant(2)), Garden.Change.INSERTED, "change")
	same(_text(path), fixed, "the file is left as it was")
	check(not DirAccess.dir_exists_absolute(path + ".lock"), "no lock taken")


func test_a_folder_that_cannot_be_written_gives_up_at_once() -> void:
	var folder := _folder("unwritable")
	var path := folder.path_join("garden.json")
	Garden.new(path).record(_plant(1))
	FileAccess.set_unix_permissions(folder, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var garden := Garden.new(path)
	var started := Time.get_ticks_msec()
	garden.record(_plant(2))
	var took := Time.get_ticks_msec() - started
	FileAccess.set_unix_permissions(folder, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	if DirAccess.dir_exists_absolute(path + ".lock") or garden.problem() == Garden.Problem.NONE:
		# Running as root (as CI may): the folder was writable after all.
		return
	same(garden.problem(), Garden.Problem.CANNOT_SAVE, "not busy: nothing can be written")
	check(took < 1000, "no five-second wait (took %d ms)" % took)


func test_a_plant_with_values_out_of_range_is_shown_never_saved() -> void:
	var path := _folder("out-of-range").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	var before := _text(path)
	var bad := _plant(2)
	bad.progress = 1.0000001
	same(garden.record(bad), Garden.Change.INSERTED, "change")
	same(garden.problem(), Garden.Problem.CANNOT_SAVE, "problem")
	same(_text(path), before, "the file is left as it was")
	same(garden.record(_plant(3)), Garden.Change.RESET, "the next plant saves")
	same(_seeds(Garden.new(path)), [3, 1] as Array[int], "without the bad one")


func test_a_garden_from_a_newer_airship_is_left_untouched() -> void:
	var path := _folder("newer").path_join("garden.json")
	var text := JSON.stringify({"version": 2, "plants": [Garden._plant_to(_plant(1))], "trains": []})
	_write(path, text)
	var garden := Garden.new(path)
	same(garden.problem(), Garden.Problem.CANNOT_READ, "problem")
	garden.record(_plant(2))
	same(_text(path), text, "the file is left as it was")


func test_a_link_to_a_garden_not_there_yet_starts_no_new_one() -> void:
	var folder := _folder("dangling")
	DirAccess.open(folder).create_link("synced/garden.json", "garden.json")
	DirAccess.make_dir_absolute(folder.path_join("synced"))
	var garden := Garden.new(folder.path_join("garden.json"))
	same(garden.problem(), Garden.Problem.CANNOT_OPEN, "problem")
	garden.record(_plant(1))
	check(not FileAccess.file_exists(folder.path_join("synced/garden.json")), "nothing written where it points")


func test_letting_go_never_removes_someone_elses_lock() -> void:
	# A garden stalled past the stale time finds its lock taken over: the
	# new holder's lock stays.
	var path := _folder("not-mine").path_join("garden.json")
	var garden := Garden.new(path)
	DirAccess.make_dir_absolute(path + ".lock")
	_write(path + ".lock/owner", "someone else")
	garden._lock_token = "mine"
	garden._let_go_of_lock()
	check(DirAccess.dir_exists_absolute(path + ".lock"), "their lock stays")


func test_fitted_parts_are_kept_with_the_plants() -> void:
	var path := _folder("fitted").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	check(not (JSON.parse_string(_text(path)) as Dictionary).has("fitted"), "nothing about parts until one is fitted")
	same(garden.fitted(), [] as Array[int], "none fitted")
	garden.fit([0, 0, 2, 1, 0] as Array[int])
	same(garden.problem(), Garden.Problem.NONE, "saved")
	var again := Garden.new(path)
	same(again.fitted(), [0, 0, 2, 1, 0] as Array[int], "read back")
	same(_seeds(again), [1] as Array[int], "the plants are still there")
	again.record(_plant(2))
	same(Garden.new(path).fitted(), [0, 0, 2, 1, 0] as Array[int], "a new plant keeps what was fitted")


func test_fitted_parts_never_go_down_and_two_windows_merge() -> void:
	var path := _folder("fitted-merge").path_join("garden.json")
	var one := Garden.new(path)
	var two := Garden.new(path)
	one.fit([0, 0, 3] as Array[int])
	two.fit([1, 0, 1, 2] as Array[int])
	same(Garden.new(path).fitted(), [1, 0, 3, 2] as Array[int], "the larger of each kind, from both windows")
	one.fit([0, 0, 0] as Array[int])
	same(one.fitted(), [1, 0, 3, 2] as Array[int], "fitting fewer takes nothing off")
	two.record(_plant(5))
	same(two.fitted(), [1, 0, 3, 2] as Array[int], "recording a plant picks up the other window's parts")


func test_a_garden_with_bad_fitted_parts_is_left_alone() -> void:
	for bad: Variant in ["three", [1, -1], [1.5], [1, "two"], null, [3e9]]:
		var path := _folder("fitted-bad").path_join("garden.json")
		var text := JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(1))], "fitted": bad})
		_write(path, text)
		var garden := Garden.new(path)
		same(garden.problem(), Garden.Problem.CANNOT_READ, "not a garden: %s" % str(bad))
		garden.fit([1] as Array[int])
		same(_text(path), text, "and never saved over")


func test_fitting_in_a_garden_kept_nowhere_still_shows() -> void:
	var garden := Garden.new("")
	garden.fit([0, 2] as Array[int])
	same(garden.fitted(), [0, 2] as Array[int], "shown")
	same(garden.problem(), Garden.Problem.NO_FOLDER, "and it says it isn't kept")


func test_parts_fitted_while_the_garden_is_busy_go_in_with_the_next_save() -> void:
	var path := _folder("fitted-busy").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	garden.lock_wait_ms = 0
	DirAccess.make_dir_absolute(path + ".lock")
	garden.fit([0, 1] as Array[int])
	same(garden.problem(), Garden.Problem.BUSY, "another Airship holds the lock")
	same(garden.fitted(), [0, 1] as Array[int], "still shown")
	DirAccess.remove_absolute(path + ".lock")
	garden.record(_plant(2))
	same(Garden.new(path).fitted(), [0, 1] as Array[int], "saved with the next plant")


func test_fitting_starts_a_garden_file_and_carries_an_unsaved_plant() -> void:
	var path := _folder("fitted-first").path_join("deeper").path_join("garden.json")
	var garden := Garden.new(path)
	garden.fit([2] as Array[int])
	same(garden.problem(), Garden.Problem.NONE, "the folder and the file are made")
	same(Garden.new(path).fitted(), [2] as Array[int], "read back from a garden with no plants")
	garden.lock_wait_ms = 0
	DirAccess.make_dir_absolute(path + ".lock")
	garden.record(_plant(7))
	DirAccess.remove_absolute(path + ".lock")
	garden.fit([3] as Array[int])
	var again := Garden.new(path)
	same(_seeds(again), [7] as Array[int], "the plant that couldn't be saved went in with the parts")
	same(again.fitted(), [3] as Array[int], "and the parts")


func test_an_older_airship_dropping_the_parts_costs_only_fitting_again() -> void:
	var path := _folder("fitted-older").path_join("garden.json")
	var garden := Garden.new(path)
	garden.record(_plant(1))
	garden.fit([0, 2] as Array[int])
	# An Airship from before parts saves the plants and nothing else.
	_write(path, JSON.stringify({"version": 1, "plants": [Garden._plant_to(_plant(1))]}))
	var fresh := Garden.new(path)
	same(fresh.problem(), Garden.Problem.NONE, "still a garden")
	same(fresh.fitted(), [] as Array[int], "a new window sees nothing fitted")
	garden.record(_plant(2))
	same(Garden.new(path).fitted(), [0, 2] as Array[int], "the window that fitted them puts them back")

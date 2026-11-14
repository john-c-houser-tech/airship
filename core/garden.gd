class_name Garden
extends RefCounted
## Every plant the arm built or left to rust, kept in one small JSON file so
## the garden fills up over days. The newest plant comes first.
##
## Grove's garden.rs is the spec. What Godot can't do the same way:
## - No file locks: a lock folder beside the file stands in (making a folder
##   succeeds for one program at a time), and one left behind by a crash is
##   treated as abandoned after STALE_LOCK_SECONDS.
## - No fsync: the garden is written beside the file and renamed into place,
##   so a crash never leaves half a garden; only a power cut at that moment
##   could lose the newest plant.

## How a session ended.
enum Outcome { BUILT, RUSTED }

## Why the garden can't be read or saved, for the window to put into words.
enum Problem {
	NONE,
	## The file is there but couldn't be opened.
	CANNOT_OPEN,
	## The file isn't a garden. It is left untouched.
	CANNOT_READ,
	## The folder for the file couldn't be made, or there is nowhere to keep it.
	NO_FOLDER,
	## Another Airship held the lock for too long.
	BUSY,
	## Writing failed; `save_error` says how.
	CANNOT_SAVE,
}

## How the list of plants changed, for a view showing it.
enum Change {
	## One plant was put first.
	INSERTED,
	## The whole list was read again.
	RESET,
}

const OUTCOME_NAMES: Array[String] = ["built", "rusted"]
## How long to wait for another Airship to finish saving.
const LOCK_WAIT_MS := 5000
## A lock folder older than this was left by a program that died holding it.
const STALE_LOCK_SECONDS := 60
const WHEN_PATTERN := "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})$"


## One plant as the garden keeps it.
class Plant:
	## Builds the same plant again.
	var blueprint := 0
	var plant_seed := 0
	var outcome := Outcome.BUILT
	## The season and the weather it was built in, by their names.
	var season := ""
	var weather := ""
	## How much of the plant was built, as the window showed it, 0 to 1.
	var progress := 0.0
	## When the session ended, local time, as YYYY-MM-DDTHH:MM:SS.
	var when := ""
	## How long the session was, if the plant was built to the end; else 0.
	var minutes := 0

	func equals(other: Plant) -> bool:
		return blueprint == other.blueprint and plant_seed == other.plant_seed and outcome == other.outcome \
			and season == other.season and weather == other.weather and progress == other.progress \
			and when == other.when and minutes == other.minutes


var lock_wait_ms := LOCK_WAIT_MS
## What went wrong saving, in the system's words, when the problem is
## CANNOT_SAVE.
var save_error := ""

var _path := ""
var _plants: Array[Plant] = []
# Plants that couldn't be saved yet (busy, no folder, a failed write), newest
# first: they go in with the next save, so a passing problem loses none.
var _unsaved: Array[Plant] = []
# Written inside the lock folder while this garden holds it, so it only ever
# lets go of its own lock.
var _lock_token := ""
var _problem := Problem.NONE
# A file that couldn't be read is left exactly as it is, so nothing is saved
# over it.
var _read_only := false


## Opens the garden kept at `path`, which need not exist yet. An empty path
## is a garden kept nowhere: its plants show, and none is saved.
func _init(path: String) -> void:
	_path = path
	if path.is_empty():
		_read_only = true
		return
	var found: Variant = _read()
	if found is Array:
		_plants = found as Array[Plant]
	elif found == Problem.CANNOT_OPEN or found == Problem.CANNOT_READ:
		_read_only = true
		_problem = found as Problem


## Where the garden is kept under the desktop's data folder:
## ~/.local/share/airship/garden.json, usually.
static func default_path(data_directory: String) -> String:
	if data_directory.is_empty():
		return ""
	return data_directory.path_join("airship/garden.json")


## The plants, newest first.
func plants() -> Array[Plant]:
	return _plants


## How many plants were built to the end.
func built() -> int:
	return _plants.filter(func(p: Plant) -> bool: return p.outcome == Outcome.BUILT).size()


## How many plants were left to rust.
func rusted() -> int:
	return _plants.size() - built()


## Time spent on plants built to the end; a rusted plant earns none.
func focused_minutes() -> int:
	var total := 0
	for p: Plant in _plants:
		if p.outcome == Outcome.BUILT:
			total += p.minutes
	return total


## NONE when the garden is fine, otherwise why it can't be read or saved.
func problem() -> Problem:
	return _problem


## Adds a plant and saves the garden. Another Airship may be open on the same
## file, so this re-reads it under the lock first and keeps the plants that
## one saved. A file that can't be read isn't saved over, and the plant is
## still shown; `problem()` says why it wasn't kept.
func record(plant: Plant) -> Change:
	# A plant the file couldn't read back would make the whole garden
	# unreadable, so one with values out of range is shown, never saved.
	if _plant_from(_plant_to(plant)) == null:
		save_error = "the plant's values are out of range"
		return _keep_unsaved(plant, Problem.CANNOT_SAVE)
	if _read_only:
		# A garden kept nowhere says so; one whose file couldn't be read has
		# said why already.
		return _keep_unsaved(plant, Problem.NO_FOLDER if _path.is_empty() else Problem.NONE)
	var folder := _path.get_base_dir()
	# Godot reports success when a file stands where the folder should be,
	# so look for the folder itself afterwards.
	DirAccess.make_dir_recursive_absolute(folder)
	if not DirAccess.dir_exists_absolute(folder):
		_unsaved.push_front(plant)
		return _keep_unsaved(plant, Problem.NO_FOLDER)
	# Only one Airship saves at a time, and each starts from the file as it is
	# now, so neither drops the plants the other has saved since it read it.
	var locked := _take_lock()
	if locked != OK:
		_unsaved.push_front(plant)
		if locked == ERR_BUSY:
			return _keep_unsaved(plant, Problem.BUSY)
		save_error = "nothing can be written beside the garden (is the disk full, or the folder read-only?)"
		return _keep_unsaved(plant, Problem.CANNOT_SAVE)
	var found: Variant = _read()
	if not found is Array:
		_let_go_of_lock()
		if found != Problem.NONE:
			# Changed into something that can't be read since: leave it be.
			_read_only = true
			return _keep_unsaved(plant, Problem.CANNOT_READ)
		found = [] as Array[Plant]
	var plants := found as Array[Plant]
	_unsaved.push_front(plant)
	for k in range(_unsaved.size() - 1, -1, -1):
		plants.push_front(_unsaved[k])
	_plants = plants
	save_error = _save()
	_let_go_of_lock()
	if save_error.is_empty():
		_unsaved.clear()
		_problem = Problem.NONE
	else:
		_problem = Problem.CANNOT_SAVE
	return Change.RESET


## Shows a plant that couldn't be kept.
func _keep_unsaved(plant: Plant, why: Problem) -> Change:
	_plants.insert(0, plant)
	if why != Problem.NONE:
		_problem = why
	return Change.INSERTED


## The file as it is now: the plants newest first, or Problem.NONE if there
## is no file, or the problem reading it.
func _read() -> Variant:
	if not FileAccess.file_exists(_path):
		# A link to a garden that isn't there (a synced folder that hasn't
		# arrived yet) isn't an empty garden: don't start a new one there.
		var dir := DirAccess.open(_path.get_base_dir())
		if dir != null and dir.is_link(_path.get_file()):
			return Problem.CANNOT_OPEN
		return Problem.NONE
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return Problem.CANNOT_OPEN
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return Problem.CANNOT_READ
	var list: Variant = (json.data as Dictionary).get("plants")
	if not list is Array:
		return Problem.CANNOT_READ
	# A garden from a newer Airship may hold what this one doesn't know of;
	# saving over it would drop that.
	if _whole((json.data as Dictionary).get("version", 1)) != 1:
		return Problem.CANNOT_READ
	# On disk the oldest plant comes first; the garden wants newest first.
	var plants: Array[Plant] = []
	for entry: Variant in list as Array:
		var plant := _plant_from(entry)
		if plant == null:
			return Problem.CANNOT_READ
		plants.push_front(plant)
	return plants


## Writes the garden beside its file and renames it into place, so a crash
## mid-write never leaves half a garden. Returns what went wrong, or "".
func _save() -> String:
	var entries: Array[Dictionary] = []
	for k in range(_plants.size() - 1, -1, -1):
		# Oldest first on disk, so a new plant is a simple append in the file.
		entries.append(_plant_to(_plants[k]))
	var text := JSON.stringify({"version": 1, "plants": entries}, "  ", false) + "\n"
	# The file itself, if the garden is a link to one kept elsewhere
	# (dotfiles, a synced folder): the link stays, and what it points at is
	# what's replaced.
	var target := _resolve_links(_path)
	var beside := "%s.%d.tmp" % [target, OS.get_process_id()]
	var file := FileAccess.open(beside, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	var stored := file.store_string(text)
	var wrote := file.get_error()
	file.close()
	if wrote == OK and not stored:
		wrote = ERR_FILE_CANT_WRITE
	# Godot writes small files out only as they close, and says nothing if
	# that fails (a full disk): read the copy back, and put it in place only
	# if it is whole, or an empty file would replace the garden.
	if wrote == OK and FileAccess.get_file_as_string(beside) != text:
		DirAccess.remove_absolute(beside)
		return "the garden couldn't be written whole (is the disk full?)"
	if wrote == OK and FileAccess.file_exists(target):
		# A garden kept private stays private.
		wrote = FileAccess.set_unix_permissions(beside, FileAccess.get_unix_permissions(target))
	if wrote == OK:
		wrote = DirAccess.rename_absolute(beside, target)
	if wrote != OK:
		DirAccess.remove_absolute(beside)
		return error_string(wrote)
	return ""


## Follows a chain of links to the file at its end.
static func _resolve_links(path: String) -> String:
	var at := path
	for k in 16:
		var dir := DirAccess.open(at.get_base_dir())
		if dir == null or not dir.is_link(at.get_file()):
			return at
		var to := dir.read_link(at.get_file())
		at = to if to.is_absolute_path() else at.get_base_dir().path_join(to).simplify_path()
	return at


func _lock_path() -> String:
	return _path + ".lock"


## Takes the right to save, waiting up to lock_wait_ms for whoever holds it.
## OK, ERR_BUSY if someone held it all that time, or ERR_CANT_CREATE if
## nothing can be written beside the garden.
func _take_lock() -> Error:
	var lock := _lock_path()
	var deadline := Time.get_ticks_msec() + lock_wait_ms
	while true:
		if not DirAccess.dir_exists_absolute(lock) and DirAccess.make_dir_absolute(lock) == OK:
			_lock_token = "%d-%d" % [OS.get_process_id(), randi()]
			var owner_file := FileAccess.open(lock.path_join("owner"), FileAccess.WRITE)
			if owner_file != null:
				owner_file.store_string(_lock_token)
				owner_file.close()
			if FileAccess.file_exists(lock.path_join("owner")) and FileAccess.get_file_as_string(lock.path_join("owner")) == _lock_token:
				return OK
			_remove_lock_folder(lock)
			return ERR_CANT_CREATE
		if not DirAccess.dir_exists_absolute(lock):
			# Not held by anyone, and still couldn't be made: the folder
			# can't be written to, and waiting won't change that.
			return ERR_CANT_CREATE
		var age := Time.get_unix_time_from_system() - FileAccess.get_modified_time(lock)
		if age > STALE_LOCK_SECONDS:
			# Left by an Airship that died holding it. Moved aside first, which
			# only one Airship can do, so two finding it at once can't both
			# take over (or remove the fresh lock the other just made).
			var aside := "%s.stale.%d-%d" % [lock, OS.get_process_id(), randi()]
			if DirAccess.rename_absolute(lock, aside) == OK:
				_remove_lock_folder(aside)
			continue
		if Time.get_ticks_msec() >= deadline:
			return ERR_BUSY
		OS.delay_msec(50)
	return ERR_BUSY


## Lets go of the lock, if it is still this garden's: one stalled past
## STALE_LOCK_SECONDS may have been taken over, and the new holder's stays.
func _let_go_of_lock() -> void:
	var owner_file := _lock_path().path_join("owner")
	if FileAccess.file_exists(owner_file) and FileAccess.get_file_as_string(owner_file) == _lock_token:
		_remove_lock_folder(_lock_path())
	_lock_token = ""


static func _remove_lock_folder(path: String) -> void:
	DirAccess.remove_absolute(path.path_join("owner"))
	DirAccess.remove_absolute(path)


## A whole number from JSON, which reads every number as a float, or -1 if
## it isn't one (a fraction, text, or too big).
static func _whole(value: Variant) -> int:
	if not (value is float or value is int):
		return -1
	var number := float(value)
	if number != floorf(number) or absf(number) > 2147483647.0:
		return -1
	return int(number)


## A plant from its entry in the file, or null if it isn't one.
static func _plant_from(entry: Variant) -> Plant:
	if not entry is Dictionary:
		return null
	var e := entry as Dictionary
	var plant := Plant.new()
	plant.blueprint = _whole(e.get("blueprint"))
	plant.plant_seed = _whole(e.get("seed"))
	var outcome := OUTCOME_NAMES.find(str(e.get("outcome", "")))
	var progress: Variant = e.get("progress")
	var when := str(e.get("when", ""))
	plant.minutes = _whole(e.get("minutes"))
	if plant.blueprint < 0 or plant.plant_seed < 0 or plant.minutes < 0 or outcome < 0:
		return null
	if not (progress is float or progress is int) or float(progress) < 0.0 or float(progress) > 1.0:
		return null
	if not _is_when(when):
		return null
	plant.outcome = outcome as Outcome
	plant.progress = float(progress)
	plant.when = when
	plant.season = str(e.get("season", "")) if e.get("season") is String else ""
	plant.weather = str(e.get("weather", "")) if e.get("weather") is String else ""
	return plant


## A plant's entry in the file.
static func _plant_to(plant: Plant) -> Dictionary:
	return {
		"blueprint": plant.blueprint,
		"seed": plant.plant_seed,
		"outcome": OUTCOME_NAMES[plant.outcome],
		"season": plant.season,
		"weather": plant.weather,
		"progress": plant.progress,
		"when": plant.when,
		"minutes": plant.minutes,
	}


## Whether text is a real moment written as YYYY-MM-DDTHH:MM:SS.
static func _is_when(text: String) -> bool:
	# The pattern's $ would also let a trailing newline through.
	if text.length() != 19:
		return false
	var found := RegEx.create_from_string(WHEN_PATTERN).search(text)
	if found == null:
		return false
	var year := found.get_string(1).to_int()
	var month := found.get_string(2).to_int()
	var day := found.get_string(3).to_int()
	if month < 1 or month > 12 or day < 1 or day > Options.days_in(year, month):
		return false
	return found.get_string(4).to_int() < 24 and found.get_string(5).to_int() < 60 and found.get_string(6).to_int() < 60

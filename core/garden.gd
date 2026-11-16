class_name Garden
extends RefCounted
## Every plant the arm built or left to rust, kept in one small JSON file so
## the garden fills up over days. The newest plant comes first. The file
## also keeps how many parts of each kind have been fitted to the airship
## (core/parts.gd says what the kinds are), and on a rusted plant whether
## its rust was scraped off: what the plants' order can't tell. And it
## keeps the valley: each airship launched moves the game on to the next,
## where a new garden and a new airship begin; every plant remembers the
## valley it was built in, and the parts fitted are the present valley's.
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
## More kinds of part than this in a file isn't a garden.
const MOST_KINDS := 64
## The garden's own reasons a save failed, in English; the window translates
## them (i18n/), while the system's own words come through as they are.
const OUT_OF_RANGE := "the plant's values are out of range"
const NOT_WHOLE := "the garden couldn't be written whole (is the disk full?)"
const NOTHING_WRITABLE := "nothing can be written beside the garden (is the disk full, or the folder read-only?)"
const REASONS: Array[String] = [OUT_OF_RANGE, NOT_WHOLE, NOTHING_WRITABLE]
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
	## For a plant left to rust: how many plants had been built to the end
	## when its rust was scraped off, or -1 while it is still seized.
	var scraped := -1
	## The valley it was built in: how many airships had been launched.
	var valley := 0

	func equals(other: Plant) -> bool:
		return blueprint == other.blueprint and plant_seed == other.plant_seed and outcome == other.outcome \
			and season == other.season and weather == other.weather and progress == other.progress \
			and when == other.when and minutes == other.minutes and scraped == other.scraped \
			and valley == other.valley


var lock_wait_ms := LOCK_WAIT_MS
## What went wrong saving, in the system's words, when the problem is
## CANNOT_SAVE.
var save_error := ""

var _path := ""
var _plants: Array[Plant] = []
# Plants that couldn't be saved yet (busy, no folder, a failed write), newest
# first: they go in with the next save, so a passing problem loses none.
var _unsaved: Array[Plant] = []
# Parts fitted to the airship, by kind; and what the file last read said.
# Fitted parts only ever grow, so two windows' counts merge by the larger.
var _fitted: Array[int] = []
var _file_fitted: Array[int] = []
# Spare parts given to the night train and parts it brought, by kind, and
# the file's: kept and merged as the fitted parts are.
var _given: Array[int] = []
var _file_given: Array[int] = []
var _brought: Array[int] = []
var _file_brought: Array[int] = []
# How many sessions had been completed in this valley at its last trade
# (0: none yet), and the file's: the larger wins.
var _traded_at := 0
var _file_traded_at := 0
# A trade being made: the kind given, how many, the kind brought, the
# valley and the parts brought so far when it was asked for, and the
# sessions completed then (the train's visit). Empty otherwise.
var _trade: Array[int] = []
# The valley the game has reached (airships launched), and the file's.
var _valley := 0
var _file_valley := 0
# Plants scraped clean here that the file may not know of yet: marked again
# on whatever is read from it, until a save goes through.
var _scrapes: Array[Plant] = []
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
		_fitted = _file_fitted.duplicate()
		_given = _file_given.duplicate()
		_brought = _file_brought.duplicate()
		_traded_at = _file_traded_at
		_valley = _file_valley
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


## The valley the game has reached: how many airships have been launched.
func valley() -> int:
	return _valley


## The present valley's plants, newest first: the garden that shows and
## works. Plants of valleys left behind stay in plants(), as history.
func valley_plants() -> Array[Plant]:
	return _plants.filter(func(plant: Plant) -> bool: return plant.valley == _valley)


## Launches the airship: on to the next valley, with nothing fitted to the
## new airship there. Saved as fit() saves.
func launch() -> void:
	_valley = mini(_valley + 1, 2147483647)
	_fitted = []
	_given = []
	_brought = []
	_traded_at = 0
	_keep()


## The parts fitted to the airship so far, by kind (as long as the longest
## count ever fitted: a kind past its end has none).
func fitted() -> Array[int]:
	return _fitted.duplicate()


## Fits parts to the airship: `counts` is the new total fitted of each kind,
## and a kind never goes down. Saved as record() saves a plant, under the
## lock and over the file as it is now; if it can't be saved it still
## shows, `problem()` says why, and it goes in with the next save (never,
## for a garden whose file can't be read or that is kept nowhere).
func fit(counts: Array[int]) -> void:
	# Only what the file can read back: no more kinds or parts than it allows.
	_fitted = _most(_fitted, _within(counts))
	_keep()


## The spare parts given to the night train so far, by kind, in this valley.
func given() -> Array[int]:
	return _given.duplicate()


## The parts the night train has brought so far, by kind, in this valley.
func brought() -> Array[int]:
	return _brought.duplicate()


## How many sessions had been completed in this valley when the night
## train last traded here; 0 if it never has.
func traded_at() -> int:
	return _traded_at


## A trade with the night train: `count` parts of the kind `gives` go,
## and one of the kind `brings` comes, after the valley's `sessions`
## completed sessions (kept, so the train trades once for each visit). Made over the file as it is now,
## under the lock, and only if no other Airship traded (or launched)
## meanwhile, nor this one already on this visit: then that trade stands,
## and this one isn't made. Nor is it made if it can't be saved. Nor
## is it made while another Airship holds the lock (`problem()` says BUSY;
## ask again). A garden whose file can't be read, or that is kept nowhere,
## trades for show, as it fits.
func trade(gives: int, count: int, brings: int, sessions: int) -> void:
	if gives < 0 or gives >= MOST_KINDS or brings < 0 or brings >= MOST_KINDS or count < 0 or sessions < 1:
		return
	_trade = [gives, count, brings, _valley, _sum(_brought), mini(sessions, 2147483647)]
	if _read_only:
		_make_trade()
	_keep()
	_trade = []


# Makes the trade asked for, if the garden is still where it was asked:
# the same valley, as many parts brought, no trade yet on this visit of
# the train or a later one, and no session since.
func _make_trade() -> void:
	if _trade.is_empty() or _trade[3] != _valley or _trade[4] != _sum(_brought) or _trade[5] <= _traded_at:
		return
	# The train has moved on if another Airship has had a session since:
	# the valley's newest plant must be the one that brought it.
	var here := valley_plants()
	var completed := 0
	for plant: Plant in here:
		if plant.outcome == Outcome.BUILT:
			completed += 1
	if completed != _trade[5] or here[0].outcome != Outcome.BUILT:
		return
	_traded_at = _trade[5]
	while _given.size() <= _trade[0]:
		_given.append(0)
	while _brought.size() <= _trade[2]:
		_brought.append(0)
	_given[_trade[0]] = mini(_given[_trade[0]] + _trade[1], 2147483647)
	_brought[_trade[2]] = mini(_brought[_trade[2]] + 1, 2147483647)
	_trade = []


static func _sum(counts: Array[int]) -> int:
	var total := 0
	for count: int in counts:
		total += count
	return total


# Counts as the file can read them back: no more kinds or parts than it
# allows.
static func _within(counts: Array[int]) -> Array[int]:
	var within: Array[int] = []
	for k in mini(counts.size(), MOST_KINDS):
		within.append(clampi(counts[k], 0, 2147483647))
	return within


## Scrapes the rust off `plant`, one of plants() left to rust: from now it
## stands and works again. `sessions` is how many plants had been built to
## the end by then (what it makes is counted from there). Saved as fit()
## saves; if it can't be saved it still shows, and goes in with the next
## save (never, for a garden whose file can't be read or that is kept
## nowhere).
func scrape(plant: Plant, sessions: int) -> void:
	if plant.outcome != Outcome.RUSTED or plant.scraped >= 0 or sessions < 0:
		return
	plant.scraped = mini(sessions, 2147483647)
	_scrapes.append(plant)
	_keep()


## Saves what changed that isn't a new plant (parts fitted, rust scraped),
## over the file as it is now and under the lock, and says in `problem()`
## how it went. What can't be saved stays shown, and waits for the next save.
func _keep() -> void:
	if _read_only:
		if _path.is_empty():
			_problem = Problem.NO_FOLDER
		return
	var folder := _path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	if not DirAccess.dir_exists_absolute(folder):
		_problem = Problem.NO_FOLDER
		return
	var locked := _take_lock()
	if locked != OK:
		if locked == ERR_BUSY:
			_problem = Problem.BUSY
		else:
			save_error = NOTHING_WRITABLE
			_problem = Problem.CANNOT_SAVE
		return
	var found: Variant = _read()
	if not found is Array:
		if found != Problem.NONE:
			_let_go_of_lock()
			_read_only = true
			_problem = Problem.CANNOT_READ
			return
		# No file yet: the lock is kept while the first one is written.
		found = [] as Array[Plant]
	var plants := found as Array[Plant]
	for k in range(_unsaved.size() - 1, -1, -1):
		plants.push_front(_unsaved[k])
	_scrape_again(plants)
	_plants = plants
	_follow_file()
	# A trade that can't be saved isn't made: shown here and not in the
	# file, another Airship could trade on the same visit, and both stand.
	var before: Array[Array] = [_given.duplicate(), _brought.duplicate()]
	var mark := _traded_at
	var trading := not _trade.is_empty()
	_make_trade()
	save_error = _save()
	if trading and not save_error.is_empty():
		_given.assign(before[0])
		_brought.assign(before[1])
		_traded_at = mark
	_let_go_of_lock()
	if save_error.is_empty():
		_unsaved.clear()
		_scrapes.clear()
		_problem = Problem.NONE
	else:
		_problem = Problem.CANNOT_SAVE


## Marks, in plants just read from the file, the ones scraped here that the
## file doesn't know of yet. A plant another Airship scraped first keeps
## that one's mark.
func _scrape_again(plants: Array[Plant]) -> void:
	for scraped: Plant in _scrapes:
		for plant: Plant in plants:
			# The first still seized: one already marked (by another Airship,
			# or a twin from the same second) is passed over.
			if plant.scraped < 0 and plant.outcome == Outcome.RUSTED and plant.plant_seed == scraped.plant_seed \
					and plant.when == scraped.when and plant.blueprint == scraped.blueprint:
				# The mark as it was made: sessions another Airship completed
				# meanwhile may earn the plant a part or two it missed. Let it.
				plant.scraped = scraped.scraped
				break


## Brings what was just read from the file together with what is known
## here: the farther valley wins, with its fitted parts; in the same
## valley, the larger count of each part (they only ever grow).
func _follow_file() -> void:
	if _file_valley > _valley:
		# Plants built here in what was the present valley, not saved yet,
		# come along: a session completed is never left behind as history.
		for plant: Plant in _unsaved:
			if plant.valley == _valley:
				plant.valley = _file_valley
		_valley = _file_valley
		_fitted = _file_fitted.duplicate()
		_given = _file_given.duplicate()
		_brought = _file_brought.duplicate()
		_traded_at = _file_traded_at
	elif _file_valley == _valley:
		_fitted = _most(_fitted, _file_fitted)
		_given = _most(_given, _file_given)
		_brought = _most(_brought, _file_brought)
		_traded_at = maxi(_traded_at, _file_traded_at)


## The larger of two counts, kind by kind.
static func _most(a: Array[int], b: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for k in maxi(a.size(), b.size()):
		out.append(maxi(a[k] if k < a.size() else 0, b[k] if k < b.size() else 0))
	return out


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
	if _plant_from(_plant_to(plant)) == null or plant.valley < 0:
		save_error = OUT_OF_RANGE
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
		save_error = NOTHING_WRITABLE
		return _keep_unsaved(plant, Problem.CANNOT_SAVE)
	var found: Variant = _read()
	if not found is Array:
		if found != Problem.NONE:
			# Changed into something that can't be read since: leave it be.
			_let_go_of_lock()
			_read_only = true
			return _keep_unsaved(plant, Problem.CANNOT_READ)
		# No file yet: the lock is kept while the first one is written, so
		# two Airships starting a garden at once don't lose one's plant.
		found = [] as Array[Plant]
	var plants := found as Array[Plant]
	_unsaved.push_front(plant)
	# What another Airship fitted since is kept too; and if one launched
	# the airship meanwhile, this plant belongs to the new valley.
	_follow_file()
	for k in range(_unsaved.size() - 1, -1, -1):
		plants.push_front(_unsaved[k])
	_scrape_again(plants)
	_plants = plants
	save_error = _save()
	_let_go_of_lock()
	if save_error.is_empty():
		_unsaved.clear()
		_scrapes.clear()
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
	_file_fitted = []
	_file_given = []
	_file_brought = []
	_file_traded_at = 0
	_file_valley = 0
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
	var version := _whole((json.data as Dictionary).get("version", 1))
	if version < 1 or version > 4:
		return Problem.CANNOT_READ
	# Parts fitted to the airship, and those traded with the night train:
	# absent in a garden from before there were any, else whole numbers,
	# none below zero.
	var counts: Array[Array] = []
	for key: String in ["fitted", "given", "brought"]:
		var entry: Variant = (json.data as Dictionary).get(key, [])
		if not entry is Array or (entry as Array).size() > MOST_KINDS:
			return Problem.CANNOT_READ
		var read: Array[int] = []
		for count: Variant in entry as Array:
			if _whole(count) < 0:
				return Problem.CANNOT_READ
			read.append(_whole(count))
		counts.append(read)
	# The sessions completed at the last trade: absent before any, and in a
	# garden from when trades waited.
	var traded_at_read := 0
	if (json.data as Dictionary).has("traded_at"):
		traded_at_read = _whole((json.data as Dictionary).get("traded_at"))
		if traded_at_read < 0:
			return Problem.CANNOT_READ
	# The valley reached: absent before any launch.
	var valley_read := 0
	if (json.data as Dictionary).has("valley"):
		valley_read = _whole((json.data as Dictionary).get("valley"))
		if valley_read < 0:
			return Problem.CANNOT_READ
	# On disk the oldest plant comes first; the garden wants newest first.
	var plants: Array[Plant] = []
	for entry: Variant in list as Array:
		var plant := _plant_from(entry)
		if plant == null:
			return Problem.CANNOT_READ
		plants.push_front(plant)
	_file_fitted.assign(counts[0])
	_file_given.assign(counts[1])
	_file_brought.assign(counts[2])
	_file_traded_at = traded_at_read
	_file_valley = valley_read
	return plants


## Writes the garden beside its file and renames it into place, so a crash
## mid-write never leaves half a garden. Returns what went wrong, or "".
func _save() -> String:
	var entries: Array[Dictionary] = []
	for k in range(_plants.size() - 1, -1, -1):
		# Oldest first on disk, so a new plant is a simple append in the file.
		entries.append(_plant_to(_plants[k]))
	# Version 1 until an airship is launched: an Airship from before parts
	# reads that file, and saving there only drops the fitted counts and the
	# scrapes (done again). From the first launch it is version 2, which
	# such an Airship leaves alone: saving there would drop the valleys,
	# and which plant belongs to which can't be worked out again.
	var valleys := _valley > 0 or _plants.any(func(plant: Plant) -> bool: return plant.valley > 0)
	# Version 4 once a trade is made (an Airship of version 3 would drop the
	# mark of the last trade, and trade again on the same visit): an Airship from before trades would
	# drop them on saving, and the spares given could be given again.
	var traded := _given.any(func(count: int) -> bool: return count > 0) \
			or _brought.any(func(count: int) -> bool: return count > 0)
	# (Version 3 was a garden whose trades waited, with no mark of the last.)
	var whole := {"version": 4 if traded else 2 if valleys else 1, "plants": entries}
	# Only once something is fitted, so a garden without parts reads as before.
	if _fitted.any(func(count: int) -> bool: return count > 0):
		whole["fitted"] = _fitted
	if traded:
		whole["given"] = _given
		whole["brought"] = _brought
		whole["traded_at"] = _traded_at
	if _valley > 0:
		whole["valley"] = _valley
	var text := JSON.stringify(whole, "  ", false) + "\n"
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
		return NOT_WHOLE
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
	# The valley it was built in: absent in the first.
	if e.has("valley"):
		plant.valley = _whole(e.get("valley"))
		if plant.valley < 0:
			return null
	# Only a rusted plant is ever scraped; the mark is absent until it is.
	if e.has("scraped"):
		plant.scraped = _whole(e.get("scraped"))
		if plant.scraped < 0 or plant.outcome != Outcome.RUSTED:
			return null
	plant.season = str(e.get("season", "")) if e.get("season") is String else ""
	plant.weather = str(e.get("weather", "")) if e.get("weather") is String else ""
	return plant


## A plant's entry in the file.
static func _plant_to(plant: Plant) -> Dictionary:
	var entry := {
		"blueprint": plant.blueprint,
		"seed": plant.plant_seed,
		"outcome": OUTCOME_NAMES[plant.outcome],
		"season": plant.season,
		"weather": plant.weather,
		"progress": plant.progress,
		"when": plant.when,
		"minutes": plant.minutes,
	}
	if plant.scraped >= 0:
		entry["scraped"] = plant.scraped
	if plant.valley > 0:
		entry["valley"] = plant.valley
	return entry


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

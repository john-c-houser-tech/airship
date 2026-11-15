extends TestCase
## The session's rules, from Grove's session.rs tests.


func _building(seconds: int) -> Session:
	var session := Session.new(seconds)
	session.start(2, 7)
	return session


## How many of `ticks` ticks of `ms` announce progress.
func _announced(session: Session, ticks: int, ms: int) -> int:
	var count := 0
	for k in ticks:
		if session.advance(ms).progress:
			count += 1
	return count


func test_starts_idle() -> void:
	var session := Session.new(10)
	same(session.state(), Session.State.IDLE, "state")
	same(session.progress(), 0.0, "progress")


func test_builds_with_time() -> void:
	var session := _building(10)
	same(session.state(), Session.State.BUILDING, "state")
	same(session.blueprint(), 2, "blueprint")
	same(session.plant_seed(), 7, "seed")
	session.advance(2500)
	same(session.progress(), 0.25, "progress")
	same(session.remaining(), 8, "remaining")


func test_finishes_when_the_time_is_up() -> void:
	var session := _building(10)
	var changes := session.advance(10_000)
	check(changes.state, "the finish is announced")
	same(session.state(), Session.State.BUILT, "state")
	same(session.progress(), 1.0, "progress")
	same(session.remaining(), 0, "remaining")


func test_giving_up_leaves_the_plant_to_rust() -> void:
	var session := _building(10)
	session.advance(4000)
	check(session.give_up().state, "giving up is announced")
	same(session.state(), Session.State.RUSTED, "state")
	# The plant keeps the size it reached, and time stops.
	session.advance(4000)
	same(session.progress(), 0.4, "progress")


func test_give_up_does_nothing_when_idle() -> void:
	var session := Session.new(10)
	var changes := session.give_up()
	check(not changes.state and not changes.progress, "nothing announced")
	same(session.state(), Session.State.IDLE, "state")


func test_starting_again_resets() -> void:
	var session := _building(10)
	session.advance(5000)
	session.give_up()
	session.start(3, 8)
	same(session.state(), Session.State.BUILDING, "state")
	same(session.progress(), 0.0, "progress")
	same(session.blueprint(), 3, "blueprint")
	same(session.plant_seed(), 8, "seed")


func test_starting_while_building_keeps_the_session() -> void:
	var session := _building(10)
	session.advance(5000)
	var changes := session.start(3, 8)
	check(not changes.state and not changes.progress, "nothing announced")
	same(session.progress(), 0.5, "progress")
	same(session.plant_seed(), 7, "seed")


func test_full_sessions_announce_progress_once_a_second() -> void:
	var session := _building(25 * 60)
	# A second of 50 ms ticks: only the countdown moving on is worth a redraw.
	same(_announced(session, 20, 50), 1, "announcements")
	same(session.remaining(), 25 * 60 - 1, "remaining")


func test_short_sessions_still_build_smoothly() -> void:
	var session := _building(10)
	same(_announced(session, 20, 50), 20, "announcements")


func test_the_end_of_a_session_is_always_announced() -> void:
	var session := _building(25 * 60)
	session.advance(25 * 60 * 1000 - 10)
	same(_announced(session, 1, 10), 1, "announcements")
	same(session.progress(), 1.0, "progress")


func test_time_running_backwards_is_ignored() -> void:
	var session := _building(10)
	session.advance(3000)
	session.advance(-2000)
	same(session.elapsed_seconds(), 3.0, "elapsed")

extends TestCase
## The launched airship's flight, as the hangar works it out.

const Hangar := preload("res://scene/hangar.gd")


func _at(seconds: float) -> Vector3:
	var hangar := Hangar.new()
	hangar._fly(seconds)
	var at := hangar._ship_origin
	hangar.free()
	return at


func test_the_flight_starts_in_the_cradle() -> void:
	check(_at(0.0).is_equal_approx(Hangar.SHIP_ORIGIN), "the ship sets off from its cradle")


func test_the_flight_is_smooth_past_the_door() -> void:
	var out := Hangar.LAUNCH_OUT_SECONDS
	var before := _at(out - 0.01).distance_to(_at(out))
	var after := _at(out).distance_to(_at(out + 0.01))
	check(before > 0.0 and after > 0.0, "the ship is moving as it clears the door")
	check(absf(before - after) < before * 0.05, "it keeps its speed past the door: %f then %f" % [before, after])


func test_the_flight_goes_out_and_up() -> void:
	var last := _at(Hangar.LAUNCH_SECONDS)
	check(last.z > Hangar.DOOR_Z + 1000.0, "the ship ends far beyond the door")
	check(last.y > Hangar.SHIP_ORIGIN.y + 100.0, "and well above its cradle")


func test_the_flight_ends() -> void:
	var hangar := Hangar.new()
	hangar.painting = Hangar.Painting.SHIP
	var daylight := Daylight.at(172, 12.5, App.DEFAULT_ACCENT)
	hangar.show_launch(daylight, Weather.Conditions.new(), 5.0)
	same(hangar.launch_seconds, 5.0, "the flight is under way")
	hangar.show_launch(daylight, Weather.Conditions.new(), Hangar.LAUNCH_SECONDS + 0.1)
	check(hangar.launch_seconds < 0.0, "and over once its time is up")
	hangar.free()

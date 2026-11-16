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


func _range(valley: int) -> Array[float]:
	var hangar := Hangar.new()
	hangar.valley = valley
	var heights: Array[float] = []
	for az in range(-70, 71, 10):
		heights.append(hangar._range_height(az))
	hangar.free()
	return heights


func test_each_valley_has_its_own_range() -> void:
	same(_range(3), _range(3), "a valley's range is the same every time")
	check(_range(0) != _range(1), "the second valley's range is not the first's")
	check(_range(1) != _range(2), "nor the third's the second's")
	for valley in 12:
		for h: float in _range(valley):
			check(h >= 1800.0 and h <= 6000.0, "valley %d's range stays a range: %f" % [valley, h])


func test_each_valley_has_its_own_colours() -> void:
	var hangar := Hangar.new()
	var cloths: Array[Color] = []
	for valley in Hangar.VALLEYS.size():
		hangar.valley = valley
		check(not cloths.has(hangar._valley_colour(2)), "valley %d's airship has its own cloth" % valley)
		cloths.append(hangar._valley_colour(2))
	same(cloths[0], Hangar.CANVAS, "the first airship is plain canvas")
	hangar.valley = Hangar.VALLEYS.size()
	same(hangar._valley_colour(2), cloths[0], "and the colours come round again")
	hangar.free()


func test_the_first_valley_is_as_it_was() -> void:
	var hangar := Hangar.new()
	for what: int in [0, 7, 40, 90]:
		same(hangar._roll(what), 0.5, "nothing is moved in the first valley")
	same(hangar._valley_colour(0), Color(0.46, 0.58, 0.40), "its far grass")
	same(hangar._valley_colour(1), Color(0.36, 0.50, 0.28), "its near grass")
	# The highest peak stands where it stood, as high as it was.
	check(absf(hangar._range_height(-6.0) - 4500.0) < 4500.0 * 0.1, "its highest peak: %f" % hangar._range_height(-6.0))
	same(hangar._snow_depth(-6.0, 2900.0), 0.0, "and its snow line")
	check(hangar._snow_depth(-6.0, 3400.0) > 0.0, "with snow above it")
	hangar.free()

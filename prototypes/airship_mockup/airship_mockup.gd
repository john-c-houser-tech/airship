extends Node
## Milestone 2 mock-up, throwaway: still pictures of the airship frame in the
## hangar, to answer gate B (does the filling frame feel like progress?).
##
## Run it: godot --path . res://prototypes/airship_mockup/airship_mockup.tscn
## Keys: 1, 2, 3 show the frame 10%, 50% and 90% built; 4 the launch; left
## and right arrows build or take away 5%.
## Flags after `--`: --built=0.5 starts at that stage; --launched starts at the
## launch; --shot=PATH saves a 1520-pixel picture of that stage and quits.

const HangarView := preload("res://prototypes/airship_mockup/hangar_view.gd")
const SHOT_SCALE := 4
const SHOT_SIZE := 1520
const SHOT_FRAMES := 3

var _view: HangarView
var _shot_path := ""
var _shot_viewport: SubViewport
var _frames := 0


func _ready() -> void:
	var built := 0.1
	var launched := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--built="):
			built = arg.trim_prefix("--built=").to_float()
		elif arg == "--launched":
			launched = true
		elif arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
	_view = HangarView.new()
	if _shot_path.is_empty():
		add_child(_view)
	else:
		# Drawn four times over and scaled down, so the edges come out smooth.
		_shot_viewport = SubViewport.new()
		_shot_viewport.size = Vector2i(760, 760) * SHOT_SCALE
		_shot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_view.scale = Vector2.ONE * SHOT_SCALE
		_shot_viewport.add_child(_view)
		add_child(_shot_viewport)
	_view.show_stage(built, launched)


func _process(_delta: float) -> void:
	if _shot_path.is_empty():
		return
	_frames += 1
	if _frames < SHOT_FRAMES:
		return
	var image := _shot_viewport.get_texture().get_image()
	image.resize(SHOT_SIZE, SHOT_SIZE, Image.INTERPOLATE_LANCZOS)
	image.save_png(_shot_path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_1: _view.show_stage(0.1, false)
		KEY_2: _view.show_stage(0.5, false)
		KEY_3: _view.show_stage(0.9, false)
		KEY_4: _view.show_stage(1.0, true)
		KEY_RIGHT: _view.show_stage(_view.built + 0.05, false)
		KEY_LEFT: _view.show_stage(_view.built - 0.05, false)

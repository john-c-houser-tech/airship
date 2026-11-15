extends Node2D
## Rain and snow falling while the arm works, drawn between the hangar's two
## pictures so they're seen only through the door (between sessions they're
## still, drawn into the outside picture, so nothing moves and nothing costs).
## Godot's particles: decoration, like the boiler's steam.

## The doorway's patch of the screen they fall over, in the scene's 760
## units, with a margin above so they enter falling.
const AREA := Rect2(80, 150, 480, 380)

var _rain: GPUParticles2D
var _snow: GPUParticles2D


func _ready() -> void:
	_rain = _particles(_streak(), 1.0, Vector3(-0.15, 1, 0), 520.0, 0.0, Vector2(1.0, 1.0))
	_snow = _particles(_flake(), 6.0, Vector3(0.05, 1, 0), 70.0, 12.0, Vector2(0.5, 1.0))
	show_weather(0.0, 0.0, false, 1.0)


## How hard it rains and snows (0 to 1), whether they move (the arm works),
## and how lit the valley is.
func show_weather(rain: float, snow: float, moving: bool, light: float) -> void:
	_rain.emitting = moving and rain > 0.0
	_snow.emitting = moving and snow > 0.0
	# Gone at once when the session ends: the still weather is painted in
	# its place, and particles left falling would keep frames being drawn.
	_rain.visible = _rain.emitting
	_snow.visible = _snow.emitting
	_rain.amount_ratio = clampf(rain, 0.05, 1.0)
	_snow.amount_ratio = clampf(snow, 0.05, 1.0)
	modulate = Color(light, light, light, 1.0)


func _particles(texture: Texture2D, life: float, direction: Vector3, speed: float, spin: float, size: Vector2) -> GPUParticles2D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(AREA.size.x * 0.6, 4, 0)
	mat.direction = direction
	mat.spread = 4.0
	mat.initial_velocity_min = speed * 0.85
	mat.initial_velocity_max = speed * 1.15
	mat.gravity = Vector3(0, 0, 0)
	mat.angular_velocity_min = -spin
	mat.angular_velocity_max = spin
	mat.scale_min = size.x
	mat.scale_max = size.y
	# Streaks lean with their fall, as the still ones do.
	mat.particle_flag_align_y = true
	var falling := GPUParticles2D.new()
	falling.position = Vector2(AREA.position.x + AREA.size.x * 0.5, AREA.position.y)
	falling.amount = 220
	falling.lifetime = life
	falling.preprocess = life
	falling.texture = texture
	falling.process_material = mat
	falling.visibility_rect = Rect2(-AREA.size.x, -20, AREA.size.x * 2, AREA.size.y + 40)
	add_child(falling)
	return falling


## A thin, pale streak of rain.
static func _streak() -> Texture2D:
	var image := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		var a := 0.15 + 0.5 * y / 13.0
		image.set_pixel(0, y, Color(0.78, 0.84, 0.94, a))
		image.set_pixel(1, y, Color(0.78, 0.84, 0.94, a * 0.6))
	return ImageTexture.create_from_image(image)


## A soft snowflake.
static func _flake() -> Texture2D:
	var flake := GradientTexture2D.new()
	flake.width = 8
	flake.height = 8
	flake.fill = GradientTexture2D.FILL_RADIAL
	flake.fill_from = Vector2(0.5, 0.5)
	flake.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 0.95))
	soft.set_color(1, Color(1, 1, 1, 0.0))
	flake.gradient = soft
	return flake

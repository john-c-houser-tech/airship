extends SceneTree
## Makes Airship's two distant sounds and writes them to sounds/: a steam
## train passing the crossing at night, and an airship flying over by day.
## They're synthesized, from Grove's synth.rs, but once and ahead of time:
## the same samples every run, so the app plays them without making them.
## The same seeds give the same files, byte for byte.
##
## Run it: bin/make-sounds (it takes a few seconds). sounds/ isn't
## committed: each remake would stay in git's history for good, so the
## package build and bin/test make them, and so does anyone running Airship
## from the repo, once.

const RATE := 22050.0
const TRAIN_SECONDS := 44.0
const AIRSHIP_SECONDS := 34.0


## A one-pole low-pass filter: air takes the highs out of far-off sound.
class LowPass:
	var alpha := 0.0
	var state := 0.0

	func _init(hz: float) -> void:
		set_cutoff(hz)

	func set_cutoff(hz: float) -> void:
		alpha = exp(-TAU * hz / RATE)

	func pass_through(x: float) -> float:
		state = alpha * state + (1.0 - alpha) * x
		return state


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://sounds"))
	_write("res://sounds/train.wav", train())
	_write("res://sounds/airship.wav", airship())
	quit()


func _write(path: String, samples: PackedFloat32Array) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for k in samples.size():
		data.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32767.0))
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(path))
	print("wrote %s: %.1f s" % [path, samples.size() / RATE])


static func _hiss(noise: Random) -> float:
	return noise.unit() * 2.0 - 1.0


## How near something passing at `passing` seconds is at `t`: 1 as it passes,
## falling away over `spread` seconds either side.
static func _nearness(t: float, passing: float, spread: float) -> float:
	var d := (t - passing) / spread
	return exp(-d * d)


## One blast of a three-chime steam whistle: three near-pure notes, each a
## touch out of tune so the chord beats, scooping up to pitch as the steam
## comes on, with breath in it.
static func _blast(out: PackedFloat32Array, start: float, seconds: float, gain: float, cutoff: float, passing: float, noise: Random) -> void:
	var notes: Array[float] = [370.0, 440.0, 554.4]
	var detune: Array[float] = [1.0, 1.005, 0.996]
	var phase: Array[float] = [0.0, 0.0, 0.0]
	var lowpass := LowPass.new(cutoff)
	var breath := LowPass.new(900.0)
	var first := int(start * RATE)
	var count := mini(int(seconds * RATE), out.size() - first)
	for i in count:
		var t := start + i / RATE
		var into := t - start
		# Sharp as the train closes in and flat once it has gone by.
		var doppler := 1.0 + 0.04 * tanh((passing - t) / 6.0)
		var scoop := 1.0 - 0.06 * exp(-into / 0.08)
		var envelope := clampf(into / 0.15, 0.0, 1.0) * clampf((seconds - into) / 0.25, 0.0, 1.0)
		var sample := 0.0
		for n in 3:
			phase[n] += TAU * notes[n] * detune[n] * doppler * scoop / RATE
			sample += sin(phase[n]) + 0.25 * sin(2.0 * phase[n]) + 0.08 * sin(3.0 * phase[n])
		sample += 0.6 * breath.pass_through(_hiss(noise))
		out[first + i] += gain * envelope * lowpass.pass_through(sample) / 3.0


## The crossing signal on the whistle: long, long, short, long.
static func _signal(out: PackedFloat32Array, start: float, gain: float, cutoff: float, last_long: float, passing: float, noise: Random) -> void:
	_blast(out, start, 2.4, gain, cutoff, passing, noise)
	_blast(out, start + 2.9, 2.4, gain, cutoff, passing, noise)
	_blast(out, start + 5.8, 0.7, gain, cutoff, passing, noise)
	_blast(out, start + 7.0, last_long, gain, cutoff, passing, noise)


## A crossing bell strike: a few inharmonic partials that die away.
static func _bell(out: PackedFloat32Array, start: float, gain: float, pitch: float) -> void:
	var ratio: Array[float] = [1.0, 1.54, 2.47, 3.35]
	var level: Array[float] = [1.0, 0.6, 0.35, 0.2]
	var decay: Array[float] = [0.3, 0.22, 0.16, 0.1]
	var first := int(start * RATE)
	for i in mini(int(RATE), out.size() - first):
		var t := i / RATE
		var sample := 0.0
		for p in 4:
			sample += level[p] * exp(-t / decay[p]) * sin(TAU * pitch * ratio[p] * t)
		out[first + i] += gain * sample


## One puff of steam from the chimney: a burst of breathy noise. A slower
## `attack` and a lower `bright` make it a softer puff.
static func _chuff(out: PackedFloat32Array, start: float, gain: float, noise: Random,
		attack := 0.012, bright := 1400.0, decay := 0.07) -> void:
	var low := LowPass.new(bright)
	var lower := LowPass.new(180.0)
	var first := int(start * RATE)
	for i in mini(int((0.15 + 1.0 * decay) * RATE), out.size() - first):
		var t := i / RATE
		var envelope := clampf(t / attack, 0.0, 1.0) * exp(-t / decay)
		var hiss := _hiss(noise)
		# The band between the two filters: the puff's breathy middle.
		out[first + i] += gain * envelope * (low.pass_through(hiss) - lower.pass_through(hiss))


## Distance in a soft echo: sound off the hills a moment later.
static func _echo(out: PackedFloat32Array, delay_seconds: float, feedback: float) -> void:
	var delay := int(delay_seconds * RATE)
	for i in range(delay, out.size()):
		out[i] += feedback * out[i - delay]


## Fades in from nothing and out to nothing, so neither end clicks; then
## scales so the loudest reaches `peak_level` of full scale.
static func _finish(out: PackedFloat32Array, seconds: float, rise: float, fall: float, peak_level: float) -> void:
	var peak := 1e-9
	for i in out.size():
		var t := i / RATE
		out[i] *= clampf(t / rise, 0.0, 1.0) * clampf((seconds - t) / fall, 0.0, 1.0)
		peak = maxf(peak, absf(out[i]))
	for i in out.size():
		out[i] = out[i] / peak * peak_level


## A steam train coming to the crossing and going by: the chuff of its
## chimney, the rails, two crossing signals on the whistle, and the bells.
static func train() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(TRAIN_SECONDS * RATE))
	var noise := Random.new(11)
	# The train reaches the crossing here; everything swells to it and fades.
	var passing := 26.0
	# The rumble of the rails.
	var slow := LowPass.new(90.0)
	var softer := LowPass.new(160.0)
	for i in out.size():
		out[i] += 4.0 * _nearness(i / RATE, passing, 8.5) * softer.pass_through(slow.pass_through(_hiss(noise)))
	# Four chuffs to a turn of the wheels, the first of each four strongest,
	# and the clickety-clack of the rail joints.
	var t := 1.5
	var beat := 0
	while t < TRAIN_SECONDS - 1.5:
		var near := _nearness(t, passing, 9.0)
		_chuff(out, t, near * (1.0 if beat % 4 == 0 else 0.6), noise)
		t += 0.23
		beat += 1
	t = 2.0
	while t < TRAIN_SECONDS - 2.0:
		var near := _nearness(t, passing, 8.5)
		for offset: float in [0.0, 0.07]:
			var tick := LowPass.new(600.0)
			var first := int((t + offset) * RATE)
			for j in int(RATE / 20.0):
				out[first + j] += 0.5 * near * exp(-j / (0.007 * RATE)) * tick.pass_through(_hiss(noise))
		t += 0.27
	# Two crossing signals: far off and soft, then closer and brighter.
	_signal(out, 3.0, 0.5, 900.0, 2.0, passing, noise)
	_signal(out, 16.0, 0.9, 1600.0, 3.0, passing, noise)
	# The crossing's bells, from before the train is there until it's clear.
	t = 12.5
	while t < 34.0:
		_bell(out, t, 0.05 + 0.25 * _nearness(t, passing, 7.0), 1450.0)
		t += 0.62
	# Everything is far away: duller, with the echo of the hills.
	var dull := LowPass.new(3200.0)
	var dull_again := LowPass.new(3200.0)
	for i in out.size():
		out[i] = dull_again.pass_through(dull.pass_through(out[i]))
	_echo(out, 0.29, 0.3)
	_finish(out, TRAIN_SECONDS, 1.5, 3.0, 0.6)
	return out


## An airship flying over: its steam engine, like the train's but slower
## and heavier, with no rails, swelling as it passes overhead and brighter
## then, duller far off. (No steam airship has ever flown; John's idea of how
## one would sound.)
static func airship() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(AIRSHIP_SECONDS * RATE))
	var noise := Random.new(23)
	var center := AIRSHIP_SECONDS / 2.0
	# Four chuffs to a turn of the engine, the first of each four strongest,
	# at a slower pace than the train's.
	var t := 1.0
	var beat := 0
	while t < AIRSHIP_SECONDS - 1.0:
		# Softer puffs than the train's: slower to start, rounder, less hiss.
		_chuff(out, t, _nearness(t, center, 9.0) * (1.0 if beat % 4 == 0 else 0.6), noise, 0.035, 1000.0, 0.09)
		t += 0.48
		beat += 1
	# Far off, the air takes the highs; overhead it's bright.
	var air_a := LowPass.new(600.0)
	var air_b := LowPass.new(600.0)
	for i in out.size():
		var cutoff := 500.0 + 900.0 * _nearness(i / RATE, center, 8.0)
		air_a.set_cutoff(cutoff)
		air_b.set_cutoff(cutoff)
		out[i] = air_b.pass_through(air_a.pass_through(out[i]))
	_echo(out, 0.29, 0.3)
	# A soft limiter rounds off the tallest puffs, so none of them is harsh.
	var top := 1e-9
	for v: float in out:
		top = maxf(top, absf(v))
	for i in out.size():
		out[i] = tanh(3.0 * out[i] / top)
	# Quieter than the train, which passes close by; this one is up high.
	_finish(out, AIRSHIP_SECONDS, 2.5, 3.5, 0.12)
	return out

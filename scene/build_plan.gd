extends RefCounted
## The arm's work for one session, as a pure function of time, carried over
## from the milestone 3 prototype (milestone 5 replaces the art). No drawing,
## no timers: ask it about any second of the session and it says where the
## arm's gripper is, what it holds and how many parts stand on the plant.
##
## Each part gets an equal slot of the session. In each slot the arm reaches
## over the parts bin, dips into it (out of sight behind its front) and
## comes up with a part, lifts it over in an arc, sets it on the plant, lets
## go and settles back to rest. The gripper's point is where the part it
## holds is, so a part set down stays exactly where the arm let it go.

const SESSION := 1500.0

# Where things are, in the 760-wide view.
## Over the parts bin on the floor, clear of its rim, and how far the
## gripper dips straight down into it.
const BIN := Vector2(652, 488)
const DIP := 102.0
const REST := Vector2(390, 400)

# The slot's phases, as fractions of the slot.
const REACH_END := 0.10
const GRIP_END := 0.16
const CARRY_END := 0.52
const PLACE_END := 0.60
const RETURN_END := 0.76

## What the arm is doing at one moment.
class Pose:
	var tip: Vector2
	## 0 closed on a part, 1 wide open.
	var open: float
	## The part in the gripper, or -1.
	var carrying: int
	## How many parts stand on the plant.
	var placed: int
	## True while the arm waits at rest between parts, or after the last:
	## nothing moves, so the window can draw less often.
	var resting: bool

var targets: Array[Vector2] = []


func _init(part_targets: Array[Vector2]) -> void:
	targets = part_targets


func pose(t: float) -> Pose:
	var p := Pose.new()
	var n := targets.size()
	var slot := SESSION / n
	var clamped := clampf(t, 0.0, SESSION)
	var index := mini(int(clamped / slot), n - 1)
	var f := (clamped - index * slot) / slot
	if t >= SESSION:
		index = n
		f = 1.0
	p.placed = index
	p.carrying = -1
	p.open = 1.0
	p.resting = false
	p.tip = REST
	if index >= n:
		p.resting = true
		return p
	var target := targets[index]
	var above := target + Vector2(0, -40)
	if f < REACH_END:
		p.tip = REST.lerp(BIN, _ease(f / REACH_END))
	elif f < GRIP_END:
		var g := (f - REACH_END) / (GRIP_END - REACH_END)
		p.tip = BIN + Vector2(0, DIP * sin(g * PI))
		# The jaws close at the bottom of the dip, inside the bin.
		p.open = 1.0 - smoothstep(0.38, 0.5, g)
		if g > 0.5:
			p.carrying = index
	elif f < CARRY_END:
		var c := _ease((f - GRIP_END) / (CARRY_END - GRIP_END))
		var straight := BIN.lerp(above, c)
		# Lift in an arc over the plant.
		p.tip = straight + Vector2(0, -150 * sin(c * PI))
		p.open = 0.0
		p.carrying = index
	elif f < PLACE_END:
		var d := (f - CARRY_END) / (PLACE_END - CARRY_END)
		p.tip = above.lerp(target, _ease(minf(d * 1.6, 1.0)))
		p.open = clampf((d - 0.7) / 0.3, 0.0, 1.0)
		p.carrying = index if d < 0.85 else -1
		p.placed = index if d < 0.85 else index + 1
	elif f < RETURN_END:
		p.placed = index + 1
		p.tip = target.lerp(REST, _ease((f - PLACE_END) / (RETURN_END - PLACE_END)))
	else:
		p.placed = index + 1
		p.resting = true
	return p


## How far into its rest the arm is at `t`, in seconds; 0 while it moves.
func rest_so_far(t: float) -> float:
	var slot := SESSION / targets.size()
	var into := fmod(clampf(t, 0.0, SESSION), slot)
	return maxf(0.0, into - RETURN_END * slot) if t < SESSION else t - SESSION


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

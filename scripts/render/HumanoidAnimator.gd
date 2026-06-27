extends Node
class_name HumanoidAnimator
## Drives a HumanoidFigure's 3D body. Movers get a real bipedal WALK CYCLE: the
## legs swing in opposite phase about the hips, the KNEE of the swinging leg
## bends so the foot lifts and clears the ground, the arms counter-swing, the
## body bobs once per footfall and leans gently into the travel direction — so a
## moving figure clearly walks on two legs instead of gliding like a wheel.
## Standing figures get a soft idle sway/breathe. It also spawns a grounded
## contact shadow under the figure.
##
## HumanoidFigure.make() wires up the joint references, `mover` and
## `height_scale`. The owner (player mesh-root / companion / enemy) is
## responsible for YAW — turning the whole body to face the travel direction —
## so this animator only swings limbs.

var body: Node3D = null         # the holder that bobs / leans
var hip_l: Node3D = null
var hip_r: Node3D = null
var knee_l: Node3D = null
var knee_r: Node3D = null
var arm_l: Node3D = null
var arm_r: Node3D = null
var mover: Node3D = null        # whose world motion drives the walk (null => idle)
var make_shadow: bool = true
var shadow_width: float = 0.62
var height_scale: float = 1.0   # so the vertical bob stays proportional to size
var swimming: bool = false      # when true, override the walk with a swim stroke

# tuning
const WALK_FREQ := 7.5          # stride cadence (rad/s base)
const IDLE_FREQ := 1.6
const LEG_SWING := 0.5          # max hip swing (rad) at full stride (~29 deg)
const ARM_SWING := 0.58
const KNEE_BEND := 0.85         # how far the swing-leg knee folds up (rad)
const WALK_BOB := 0.05          # vertical bob per footfall (m, * height_scale)
const IDLE_BOB := 0.01
const LEAN := 0.08              # forward lean (rad) at full stride
const TARGET_SPEED := 4.5       # m/s that counts as a full-amplitude stride
const MOVE_THRESHOLD := 0.5     # m/s before "walking" kicks in
const SWIM_FREQ := 3.6          # swim-stroke cadence (rad/s)
const SWIM_PITCH := 0.85        # forward pitch of the body while swimming (rad)

var _base_body_y: float = 0.0
var _t: float = 0.0
var _phase: float = 0.0
var _prev: Vector3 = Vector3.ZERO
var _have_prev: bool = false
var _speed: float = 0.0
var _gait: float = 0.0          # smoothed 0..1 walk blend (eases start/stop)
var _impulse: float = 0.0       # transient nod, decays to 0


func _ready() -> void:
	if body != null:
		_base_body_y = body.position.y
	_phase = randf() * TAU
	_t = randf() * TAU
	if make_shadow:
		_spawn_shadow()


## Grounded contact shadow as a child of the figure root (sibling of `body`), so
## the walk bob never lifts it off the floor.
func _spawn_shadow() -> void:
	var root := get_parent()
	if root == null:
		return
	var shadow := CharacterBillboard.make_ground_shadow(maxf(0.4, shadow_width))
	shadow.position = Vector3(0, 0.035, 0)
	root.add_child(shadow)


## A short upward "perk" used as an acknowledging nod when talked to.
func nudge(strength: float = 0.07) -> void:
	_impulse = maxf(_impulse, strength)


## Find the HumanoidAnimator anywhere under a character root.
static func find_in(root: Node) -> HumanoidAnimator:
	if root == null:
		return null
	for c in root.get_children():
		if c is HumanoidAnimator:
			return c as HumanoidAnimator
		var f := find_in(c)
		if f != null:
			return f
	return null


func _process(delta: float) -> void:
	if body == null or delta <= 0.0:
		return

	if swimming:
		_swim(delta)
		return

	# --- measure travel speed from the mover's horizontal displacement ---
	var inst_speed := 0.0
	if mover != null and is_instance_valid(mover):
		var p: Vector3 = mover.global_position
		if _have_prev:
			var d: Vector3 = p - _prev
			inst_speed = minf(Vector2(d.x, d.z).length() / delta, 12.0)
		_prev = p
		_have_prev = true
	_speed = lerpf(_speed, inst_speed, clampf(delta * 10.0, 0.0, 1.0))

	var moving := _speed > MOVE_THRESHOLD
	var target_gait := 1.0 if moving else 0.0
	_gait = lerpf(_gait, target_gait, clampf(delta * 8.0, 0.0, 1.0))
	_impulse = maxf(0.0, _impulse - delta * 0.22)

	# Phase advances with cadence (a touch faster when moving quickly).
	var stride := clampf(_speed / TARGET_SPEED, 0.0, 1.4)
	var freq := lerpf(IDLE_FREQ, WALK_FREQ * clampf(stride, 0.6, 1.4), _gait)
	_phase += delta * freq
	_t += delta * IDLE_FREQ
	var swing := sin(_phase)
	var amp_scale := minf(stride, 1.0) * _gait

	# --- legs: opposite-phase hip swing; arms counter-swing ---
	var leg_amp := LEG_SWING * amp_scale
	var arm_amp := ARM_SWING * amp_scale
	if is_instance_valid(hip_l):
		hip_l.rotation.x = swing * leg_amp
	if is_instance_valid(hip_r):
		hip_r.rotation.x = -swing * leg_amp
	if is_instance_valid(arm_l):
		arm_l.rotation.x = -swing * arm_amp
		arm_l.rotation.y = lerpf(arm_l.rotation.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if is_instance_valid(arm_r):
		arm_r.rotation.x = swing * arm_amp
		arm_r.rotation.y = lerpf(arm_r.rotation.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))

	# --- knees: the leg swinging FORWARD folds up so the foot clears the ground;
	# the planted (rear) leg stays straight. Negative rotation tucks the shin back.
	var knee_amp := KNEE_BEND * amp_scale
	if is_instance_valid(knee_l):
		knee_l.rotation.x = -maxf(0.0, swing) * knee_amp
	if is_instance_valid(knee_r):
		knee_r.rotation.x = -maxf(0.0, -swing) * knee_amp

	# --- body: bob once per footfall (|sin|), idle breathe, lean into travel ---
	var walk_bob := absf(swing) * WALK_BOB * height_scale * _gait
	var idle_bob := sin(_t) * IDLE_BOB * height_scale * (1.0 - _gait)
	body.position.y = _base_body_y + walk_bob + idle_bob + _impulse
	var lean_target := LEAN * minf(stride, 1.0) * _gait
	body.rotation.x = lerpf(body.rotation.x, lean_target, clampf(delta * 6.0, 0.0, 1.0))
	# Subtle idle weight-shift when standing still.
	body.rotation.z = sin(_t * 0.6) * 0.018 * (1.0 - _gait)


## A front-crawl swim cycle: the body pitches forward into the water and bobs,
## the arms windmill overhead in alternation, and the legs flutter-kick. Used by
## the pilgrim while crossing the River of Death (PlayerController.set_swimming).
func _swim(delta: float) -> void:
	_phase += delta * SWIM_FREQ
	var sw := sin(_phase)
	# Body: pitch forward (face toward the water) and rise/fall with the stroke.
	body.rotation.x = lerpf(body.rotation.x, SWIM_PITCH, clampf(delta * 4.0, 0.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	body.position.y = _base_body_y + sin(_phase * 2.0) * 0.06 * height_scale
	# Arms: alternating overhead crawl. arm pivot rot.x ~ -2.4 (reach overhead) to
	# +0.6 (pull through under the body); the two arms are half a cycle apart.
	if is_instance_valid(arm_l):
		arm_l.rotation.x = -0.9 + sw * 1.5
	if is_instance_valid(arm_r):
		arm_r.rotation.x = -0.9 - sw * 1.5
	# Legs: small flutter kick, knees barely bent (trailing in the water).
	if is_instance_valid(hip_l):
		hip_l.rotation.x = sw * 0.3
	if is_instance_valid(hip_r):
		hip_r.rotation.x = -sw * 0.3
	if is_instance_valid(knee_l):
		knee_l.rotation.x = -0.18 - maxf(0.0, sw) * 0.18
	if is_instance_valid(knee_r):
		knee_r.rotation.x = -0.18 - maxf(0.0, -sw) * 0.18

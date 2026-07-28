extends Node
class_name HumanoidAnimator
## Drives a HumanoidFigure's 3D body.
##
## 2026 motion pass. What the old version did: one sine wave swung the hips and
## arms, the knee folded, the body bobbed. What it could not do — and what
## players read instantly as "puppet" — was:
##
##   * FOOT SLIDING. Cadence was a constant (WALK_FREQ) scaled loosely by speed,
##     so the feet never matched ground travel. Now the phase is STRIDE-LOCKED:
##     frequency is derived from speed / step_length, so one stride moves the
##     figure exactly one step. This single change is most of the difference.
##   * No ankle. Feet stayed flat and stabbed into the ground. Now the ankle
##     rolls through heel-strike -> flat -> toe-off.
##   * No elbow. Arms were rigid poles. Now the forearm folds on the forward
##     swing and hangs on the back swing.
##   * No head. The head was welded facing forward forever. Now it turns toward
##     whoever is talking (or the travel direction), drifts while idle, and
##     BLINKS.
##   * No breathing, no cloth, no weight. Now the chest expands, the hem swings
##     against the stride, and starting/stopping produces a real weight shift
##     (lean overshoot on launch, settle-back on stop).
##   * No slope. On a hill the figure stayed vertical. Now it pitches to the
##     floor normal when the mover is a CharacterBody3D.
##   * No idle variation. Standing NPCs looped one sway forever. Now they play
##     occasional idle breaks (weight shift, glance, shoulder roll).
##
## HumanoidFigure.make() wires up every joint reference. The owner (player
## mesh-root / companion / enemy) still owns YAW; this animator only drives the
## body.

# --- joints (wired by HumanoidFigure.make) ---
var body: Node3D = null         # the holder that bobs / leans
var chest: Node3D = null        # breathing + torso twist
var head: Node3D = null         # HeadPivot: look-at, tilt, nod
var eye_l: Node3D = null
var eye_r: Node3D = null
var hem: Node3D = null          # garment, swings against the stride
var hip_l: Node3D = null
var hip_r: Node3D = null
var knee_l: Node3D = null
var knee_r: Node3D = null
var ankle_l: Node3D = null
var ankle_r: Node3D = null
var arm_l: Node3D = null
var arm_r: Node3D = null
var elbow_l: Node3D = null
var elbow_r: Node3D = null

var mover: Node3D = null        # whose world motion drives the walk (null => idle)
var make_shadow: bool = true
var shadow_width: float = 0.62
var height_scale: float = 1.0
var step_length: float = 0.86   # metres of ground travel per step (stride lock)
var seed_offset: float = 0.0    # de-syncs crowds so they don't breathe in unison
var swimming: bool = false
var mud_struggling: bool = false
var struggle_intensity: float = 0.0

## Optional world-space point the head should look at (set by dialogue / NPC
## code). Cleared with clear_look_target().
var look_target: Node3D = null

# tuning
const IDLE_FREQ := 1.6
const LEG_SWING := 0.52
const ARM_SWING := 0.56
const KNEE_BEND := 0.9
const ELBOW_BEND := 0.62
const ANKLE_ROLL := 0.42
const WALK_BOB := 0.045
const IDLE_BOB := 0.01
const LEAN := 0.09
const MOVE_THRESHOLD := 0.35
const MAX_CADENCE := 13.0       # rad/s ceiling so a sprint can't blur the legs
const MIN_CADENCE := 3.2
const SWIM_FREQ := 3.6
const SWIM_PITCH := 0.85
const STRUGGLE_FREQ := 4.8
const HEAD_YAW_LIMIT := 1.05    # ~60 deg
const HEAD_PITCH_LIMIT := 0.55
const TURN_LEAN := 0.5          # counter-lean per rad/s of yaw rate

var _base_body_y: float = 0.0
var _t: float = 0.0
var _phase: float = 0.0
var _prev: Vector3 = Vector3.ZERO
var _have_prev: bool = false
var _speed: float = 0.0
var _gait: float = 0.0
var _impulse: float = 0.0
var _accel: float = 0.0         # smoothed d(speed)/dt — drives the weight shift
var _prev_speed: float = 0.0
var _yaw_rate: float = 0.0
var _prev_yaw: float = 0.0
var _have_yaw: bool = false
var _blink_t: float = 1.5
var _blink_phase: float = 0.0
var _idle_break_t: float = 4.0
var _idle_break: int = -1       # -1 none, else index of the running break
var _idle_break_time: float = 0.0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0
var _slope_pitch: float = 0.0
var _slope_roll: float = 0.0


func _ready() -> void:
	if body != null:
		_base_body_y = body.position.y
	_phase = randf() * TAU
	_t = randf() * TAU + seed_offset * 10.0
	_blink_t = randf_range(1.2, 4.5)
	_idle_break_t = randf_range(3.0, 9.0)
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
	root.add_child.call_deferred(shadow)


## A short upward "perk" used as an acknowledging nod when talked to.
func nudge(strength: float = 0.07) -> void:
	_impulse = maxf(_impulse, strength)


## Make this figure turn its head toward `target` (usually the player) until
## clear_look_target() is called. Used when a conversation starts.
func look_at_node(target: Node3D) -> void:
	look_target = target


func clear_look_target() -> void:
	look_target = null


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

	if mud_struggling:
		_struggle(delta)
		_face(delta)
		return
	if swimming:
		_swim(delta)
		return

	_measure(delta)
	_walk(delta)
	_face(delta)


# --------------------------------------------------------------- measurement

func _measure(delta: float) -> void:
	var inst_speed := 0.0
	if mover != null and is_instance_valid(mover):
		var p: Vector3 = mover.global_position
		if _have_prev:
			var d: Vector3 = p - _prev
			inst_speed = minf(Vector2(d.x, d.z).length() / delta, 14.0)
		_prev = p
		_have_prev = true
	_speed = lerpf(_speed, inst_speed, clampf(delta * 12.0, 0.0, 1.0))
	var raw_accel := (_speed - _prev_speed) / maxf(delta, 0.0001)
	_accel = lerpf(_accel, clampf(raw_accel, -20.0, 20.0), clampf(delta * 8.0, 0.0, 1.0))
	_prev_speed = _speed

	# Yaw rate of the body we hang under — drives turn-in-place counter-lean.
	var yaw_src: Node3D = body.get_parent() as Node3D
	if yaw_src != null:
		var y: float = yaw_src.global_rotation.y
		if _have_yaw:
			var dy: float = wrapf(y - _prev_yaw, -PI, PI)
			_yaw_rate = lerpf(_yaw_rate, dy / maxf(delta, 0.0001), clampf(delta * 10.0, 0.0, 1.0))
		_prev_yaw = y
		_have_yaw = true

	# Slope: only when the mover is a real body that reports a floor normal.
	# (No raycasts — this must stay free for 40+ figures on the web build.)
	var target_pitch := 0.0
	var target_roll := 0.0
	if mover is CharacterBody3D:
		var cb := mover as CharacterBody3D
		if cb.is_on_floor():
			var n: Vector3 = cb.get_floor_normal()
			if n.length_squared() > 0.01:
				var local_n: Vector3 = body.global_transform.basis.inverse() * n
				target_pitch = clampf(-atan2(local_n.z, local_n.y), -0.35, 0.35)
				target_roll = clampf(atan2(local_n.x, local_n.y), -0.3, 0.3)
	_slope_pitch = lerpf(_slope_pitch, target_pitch, clampf(delta * 5.0, 0.0, 1.0))
	_slope_roll = lerpf(_slope_roll, target_roll, clampf(delta * 5.0, 0.0, 1.0))


# ------------------------------------------------------------------ walk cycle

func _walk(delta: float) -> void:
	var moving := _speed > MOVE_THRESHOLD
	var target_gait := 1.0 if moving else 0.0
	_gait = lerpf(_gait, target_gait, clampf(delta * 9.0, 0.0, 1.0))
	_impulse = maxf(0.0, _impulse - delta * 0.22)

	# --- STRIDE LOCK -------------------------------------------------------
	# One half-cycle of the sine == one step == `step_length` metres of travel.
	# cadence(rad/s) = PI * speed / step_length. The feet therefore advance at
	# exactly ground speed and stop sliding, which is the whole point.
	var cadence := clampf(PI * _speed / maxf(step_length, 0.05), MIN_CADENCE, MAX_CADENCE)
	var freq := lerpf(IDLE_FREQ, cadence, _gait)
	_phase += delta * freq
	_t += delta * IDLE_FREQ
	var swing := sin(_phase)

	# Amplitude tracks stride length rather than raw speed, so a slow burdened
	# walk takes short steps and a free walk takes long ones.
	var stride := clampf(_speed / 4.5, 0.0, 1.25)
	var amp := minf(stride, 1.0) * _gait

	# --- turn in place: shuffle the feet a little when pivoting while stopped --
	var turn := clampf(_yaw_rate, -3.0, 3.0)
	var pivot_shuffle := absf(turn) * 0.12 * (1.0 - _gait)

	# --- legs -------------------------------------------------------------
	var leg_amp := LEG_SWING * amp
	if is_instance_valid(hip_l):
		hip_l.rotation.x = swing * leg_amp + sin(_t * 3.1) * pivot_shuffle
	if is_instance_valid(hip_r):
		hip_r.rotation.x = -swing * leg_amp - sin(_t * 3.1) * pivot_shuffle

	# Knees: the forward-swinging leg folds so the foot clears the ground; the
	# planted leg keeps a small compliance bend so it never locks rigid.
	var knee_amp := KNEE_BEND * amp
	var stand_bend := -0.06 - 0.05 * (1.0 - _gait)
	if is_instance_valid(knee_l):
		knee_l.rotation.x = stand_bend - maxf(0.0, swing) * knee_amp
	if is_instance_valid(knee_r):
		knee_r.rotation.x = stand_bend - maxf(0.0, -swing) * knee_amp

	# Ankles: heel-strike (toe up) as the leg reaches forward, toe-off (toe down)
	# as it pushes back. Offset a quarter cycle from the hip.
	var roll := ANKLE_ROLL * amp
	if is_instance_valid(ankle_l):
		ankle_l.rotation.x = -swing * roll + maxf(0.0, swing) * roll * 0.7
	if is_instance_valid(ankle_r):
		ankle_r.rotation.x = swing * roll + maxf(0.0, -swing) * roll * 0.7

	# --- arms: counter-swing with a folding elbow -------------------------
	var arm_amp := ARM_SWING * amp
	var ease := clampf(delta * 8.0, 0.0, 1.0)
	if is_instance_valid(arm_l):
		arm_l.rotation.x = -swing * arm_amp
		arm_l.rotation.y = lerpf(arm_l.rotation.y, 0.0, ease)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.06, ease)
	if is_instance_valid(arm_r):
		arm_r.rotation.x = swing * arm_amp
		arm_r.rotation.y = lerpf(arm_r.rotation.y, 0.0, ease)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.06, ease)
	# Elbow folds most when the arm is forward (negative shoulder rotation).
	var elbow_amp := ELBOW_BEND * amp
	var rest_fold := -0.12
	if is_instance_valid(elbow_l):
		elbow_l.rotation.x = rest_fold - maxf(0.0, -swing) * elbow_amp
	if is_instance_valid(elbow_r):
		elbow_r.rotation.x = rest_fold - maxf(0.0, swing) * elbow_amp

	# --- body: bob, breathe, lean, weight-shift ---------------------------
	var walk_bob := absf(swing) * WALK_BOB * height_scale * _gait
	var idle_bob := sin(_t + seed_offset) * IDLE_BOB * height_scale * (1.0 - _gait)
	body.position.y = _base_body_y + walk_bob + idle_bob + _impulse

	# Weight shift: leaning INTO acceleration and settling BACK on deceleration
	# is what sells starting and stopping. Without it a figure teleports between
	# "standing" and "walking".
	var weight := clampf(_accel * 0.035, -0.09, 0.12)
	var lean_target := LEAN * minf(stride, 1.0) * _gait + weight + _slope_pitch
	body.rotation.x = lerpf(body.rotation.x, lean_target, clampf(delta * 7.0, 0.0, 1.0))

	var roll_target := -turn * TURN_LEAN * 0.12 + _slope_roll
	roll_target += sin(_t * 0.6 + seed_offset) * 0.018 * (1.0 - _gait)
	body.rotation.z = lerpf(body.rotation.z, roll_target, clampf(delta * 6.0, 0.0, 1.0))

	# Torso counter-rotates against the hips — real walkers twist.
	if is_instance_valid(chest):
		chest.rotation.y = lerpf(chest.rotation.y, -swing * 0.10 * amp, clampf(delta * 10.0, 0.0, 1.0))
		# Breathing: the chest expands. Faster and deeper when moving.
		var breath := 1.0 + sin(_t * lerpf(1.0, 2.1, _gait) + seed_offset) * lerpf(0.012, 0.026, _gait)
		chest.scale = Vector3(breath, 1.0, breath)

	# Cloth: the hem lags the stride and swings against it.
	if is_instance_valid(hem):
		hem.rotation.x = lerpf(hem.rotation.x, -swing * 0.09 * amp - lean_target * 0.35,
			clampf(delta * 7.0, 0.0, 1.0))
		hem.rotation.z = lerpf(hem.rotation.z, turn * 0.08, clampf(delta * 5.0, 0.0, 1.0))


# ------------------------------------------------------- head, eyes, idle life

func _face(delta: float) -> void:
	_blink(delta)
	_idle_life(delta)
	if not is_instance_valid(head):
		return

	var want_yaw := 0.0
	var want_pitch := 0.0
	if look_target != null and is_instance_valid(look_target):
		# Convert the world-space target into the head's parent space so the
		# limits below are measured against the body's own facing.
		var parent := head.get_parent() as Node3D
		if parent != null:
			var local: Vector3 = parent.global_transform.affine_inverse() * look_target.global_position
			local.y -= head.position.y
			if local.length_squared() > 0.04:
				want_yaw = clampf(atan2(local.x, local.z), -HEAD_YAW_LIMIT, HEAD_YAW_LIMIT)
				var flat: float = Vector2(local.x, local.z).length()
				want_pitch = clampf(-atan2(local.y, maxf(flat, 0.05)), -HEAD_PITCH_LIMIT, HEAD_PITCH_LIMIT)
	else:
		# Idle: a slow, small drift so the head is never perfectly still.
		want_yaw = sin(_t * 0.31 + seed_offset * 3.0) * 0.16 * (1.0 - _gait)
		want_pitch = sin(_t * 0.23 + seed_offset) * 0.06 * (1.0 - _gait)
		# Walking: look slightly into the turn.
		want_yaw += clampf(_yaw_rate, -2.0, 2.0) * 0.10 * _gait

	if _idle_break == 1:
		want_yaw += sin(_idle_break_time * 2.2) * 0.5

	_head_yaw = lerpf(_head_yaw, want_yaw, clampf(delta * 5.0, 0.0, 1.0))
	_head_pitch = lerpf(_head_pitch, want_pitch, clampf(delta * 5.0, 0.0, 1.0))
	head.rotation.y = _head_yaw
	head.rotation.x = _head_pitch
	# A little head tilt reads as personality and costs nothing.
	head.rotation.z = lerpf(head.rotation.z, -_head_yaw * 0.12, clampf(delta * 4.0, 0.0, 1.0))


func _blink(delta: float) -> void:
	if not (is_instance_valid(eye_l) or is_instance_valid(eye_r)):
		return
	if _blink_phase > 0.0:
		_blink_phase = maxf(0.0, _blink_phase - delta * 7.5)
		# 1 -> 0 over ~0.13 s; squash the lids closed at the peak.
		var closed := sin(clampf(1.0 - _blink_phase, 0.0, 1.0) * PI)
		var sy := 1.0 - closed * 0.92
		if is_instance_valid(eye_l):
			eye_l.scale = Vector3(1.0, sy, 1.0)
		if is_instance_valid(eye_r):
			eye_r.scale = Vector3(1.0, sy, 1.0)
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_phase = 1.0
		_blink_t = randf_range(1.8, 6.0)


## Occasional idle breaks so standing NPCs stop looping one sway forever.
func _idle_life(delta: float) -> void:
	if _gait > 0.15:
		_idle_break = -1
		return
	if _idle_break >= 0:
		_idle_break_time += delta
		var dur := 1.6
		match _idle_break:
			0:  # weight shift onto one hip
				if is_instance_valid(body):
					body.rotation.z += sin(_idle_break_time * 1.6) * 0.012
			1:  # glance around (handled in _face)
				dur = 2.4
			2:  # shoulder roll
				if is_instance_valid(arm_l) and is_instance_valid(arm_r):
					var r := sin(_idle_break_time * 2.4) * 0.13
					arm_l.rotation.z = 0.06 + r
					arm_r.rotation.z = -0.06 - r
		if _idle_break_time > dur:
			_idle_break = -1
			_idle_break_t = randf_range(4.0, 11.0)
		return
	_idle_break_t -= delta
	if _idle_break_t <= 0.0:
		_idle_break = randi() % 3
		_idle_break_time = 0.0


# ------------------------------------------------------------ special gaits

## A front-crawl swim cycle used while crossing the River of Death.
func _swim(delta: float) -> void:
	_phase += delta * SWIM_FREQ
	var sw := sin(_phase)
	var ease := clampf(delta * 4.0, 0.0, 1.0)
	body.rotation.x = lerpf(body.rotation.x, SWIM_PITCH, ease)
	body.rotation.z = lerpf(body.rotation.z, sw * 0.09, ease)
	body.position.y = _base_body_y + sin(_phase * 2.0) * 0.06 * height_scale
	if is_instance_valid(chest):
		chest.rotation.y = lerpf(chest.rotation.y, sw * 0.22, ease)
		chest.scale = Vector3.ONE
	if is_instance_valid(arm_l):
		arm_l.rotation.x = -0.9 + sw * 1.5
	if is_instance_valid(arm_r):
		arm_r.rotation.x = -0.9 - sw * 1.5
	if is_instance_valid(elbow_l):
		elbow_l.rotation.x = -0.35 - maxf(0.0, sw) * 0.5
	if is_instance_valid(elbow_r):
		elbow_r.rotation.x = -0.35 - maxf(0.0, -sw) * 0.5
	if is_instance_valid(hip_l):
		hip_l.rotation.x = sw * 0.3
	if is_instance_valid(hip_r):
		hip_r.rotation.x = -sw * 0.3
	if is_instance_valid(knee_l):
		knee_l.rotation.x = -0.18 - maxf(0.0, sw) * 0.18
	if is_instance_valid(knee_r):
		knee_r.rotation.x = -0.18 - maxf(0.0, -sw) * 0.18
	if is_instance_valid(ankle_l):
		ankle_l.rotation.x = 0.3
	if is_instance_valid(ankle_r):
		ankle_r.rotation.x = 0.3
	# The head lifts for air on every other stroke.
	if is_instance_valid(head):
		head.rotation.x = lerpf(head.rotation.x, -0.45 + maxf(0.0, sw) * 0.35, ease)
		head.rotation.y = lerpf(head.rotation.y, sw * 0.3, ease)
	_blink(delta)


## A laboured, mostly upright stroke for the Slough of Despond.
func _struggle(delta: float) -> void:
	var strength := clampf(struggle_intensity, 0.0, 1.0)
	_phase += delta * lerpf(3.5, STRUGGLE_FREQ, strength)
	var sw := sin(_phase)
	var churn := cos(_phase * 0.82)
	var ease := clampf(delta * 6.0, 0.0, 1.0)
	body.rotation.x = lerpf(body.rotation.x, lerpf(0.2, 0.42, strength), ease)
	body.rotation.z = lerpf(body.rotation.z, sw * 0.11 * strength, ease)
	body.position.y = _base_body_y + (absf(churn) * 0.07 - 0.025) * height_scale * strength
	if is_instance_valid(chest):
		chest.rotation.y = lerpf(chest.rotation.y, -sw * 0.18 * strength, ease)
		var gasp := 1.0 + sin(_phase * 1.6) * 0.045 * strength
		chest.scale = Vector3(gasp, 1.0, gasp)
	if is_instance_valid(arm_l):
		arm_l.rotation.x = -0.72 + sw * lerpf(0.75, 1.2, strength)
		arm_l.rotation.y = 0.28 + churn * 0.42 * strength
		arm_l.rotation.z = -0.28 - churn * 0.24 * strength
	if is_instance_valid(arm_r):
		arm_r.rotation.x = -0.72 - sw * lerpf(0.75, 1.2, strength)
		arm_r.rotation.y = -0.28 + churn * 0.42 * strength
		arm_r.rotation.z = 0.28 + churn * 0.24 * strength
	if is_instance_valid(elbow_l):
		elbow_l.rotation.x = -0.5 - maxf(0.0, churn) * 0.55 * strength
	if is_instance_valid(elbow_r):
		elbow_r.rotation.x = -0.5 - maxf(0.0, -churn) * 0.55 * strength
	if is_instance_valid(hip_l):
		hip_l.rotation.x = 0.18 + sw * 0.42 * strength
	if is_instance_valid(hip_r):
		hip_r.rotation.x = 0.18 - sw * 0.42 * strength
	if is_instance_valid(knee_l):
		knee_l.rotation.x = -0.3 - maxf(0.0, -sw) * 0.55 * strength
	if is_instance_valid(knee_r):
		knee_r.rotation.x = -0.3 - maxf(0.0, sw) * 0.55 * strength
	if is_instance_valid(head):
		head.rotation.x = lerpf(head.rotation.x, -0.22 * strength, ease)
	_blink(delta)

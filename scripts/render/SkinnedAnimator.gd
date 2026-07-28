extends HumanoidAnimator
class_name SkinnedAnimator
## Drives the SKINNED pilgrim (assets/characters/rig/pilgrim.glb).
##
## It deliberately EXTENDS HumanoidAnimator rather than replacing it, because
## nine call sites across the project reach a character's motion through
## `HumanoidAnimator.find_in(root)` and then use `nudge()`, `look_at_node()`,
## `swimming`, `mud_struggling` and `struggle_intensity`. Subclassing means the
## skinned figure is a drop-in: every one of those callers keeps working with no
## edit, and a chapter that falls back to the primitive figure behaves the same.
##
## What changes is the OUTPUT. The base class rotates ~14 rigid child nodes
## itself; this class instead:
##
##   * picks an animation clip (Idle / Walk / Run / Talk / Swim / Struggle),
##   * cross-fades to it with AnimationPlayer's blend time,
##   * STRIDE-LOCKS it by driving `speed_scale` from the measured ground speed,
##     so the skinned walk has the same "feet do not slide" property as the
##     primitive one, and
##   * layers head look-at and blinking on top through a SkeletonModifier3D,
##     which is the only place Godot guarantees will not be overwritten by the
##     AnimationPlayer.

var player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var model_root: Node3D = null

## Metres of ground travel one loop of the Walk clip should cover. The clip is
## authored as a full two-step cycle, so this is 2 x step length.
var walk_cycle_distance: float = 1.72
var run_cycle_distance: float = 2.35

const BLEND := 0.22
const RUN_SPEED := 5.6      # m/s at which Run takes over from Walk
const CLIP_IDLE := "Idle"
const CLIP_WALK := "Walk"
const CLIP_RUN := "Run"
const CLIP_TALK := "Talk"
const CLIP_SWIM := "Swim"
const CLIP_STRUGGLE := "Struggle"

var _override: SkeletonPoseOverride = null
var _clip: String = ""
var _look_weight: float = 0.0
var _talk_hold: float = 0.0


func _ready() -> void:
	# Deliberately NOT calling super(): the base class caches child-node poses
	# and spawns a blob shadow sized for the primitive figure. The skinned model
	# casts a real shadow, and has no such child nodes.
	_blink_reset()
	if make_shadow:
		_spawn_shadow()
	if skeleton != null:
		_override = SkeletonPoseOverride.new()
		_override.name = "PoseOverride"
		skeleton.add_child(_override)
	if player != null:
		for a in [CLIP_IDLE, CLIP_WALK, CLIP_RUN, CLIP_TALK, CLIP_SWIM, CLIP_STRUGGLE]:
			var anim := player.get_animation(a)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		_play(CLIP_IDLE, 0.0)


func _blink_reset() -> void:
	_blink_t = randf_range(1.2, 4.5)
	_t = randf() * TAU + seed_offset * 10.0


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_measure(delta)
	_t += delta
	_choose_clip(delta)
	_drive_head(delta)


# ------------------------------------------------------------------- clips

func _choose_clip(delta: float) -> void:
	if player == null:
		return
	var moving := _speed > MOVE_THRESHOLD
	_gait = lerpf(_gait, 1.0 if moving else 0.0, clampf(delta * 9.0, 0.0, 1.0))

	var want := CLIP_IDLE
	var scale := 1.0

	if mud_struggling:
		want = CLIP_STRUGGLE
		scale = lerpf(0.7, 1.35, clampf(struggle_intensity, 0.0, 1.0))
	elif swimming:
		want = CLIP_SWIM
		scale = clampf(0.75 + _speed * 0.16, 0.7, 1.7)
	elif moving:
		if _speed >= RUN_SPEED:
			want = CLIP_RUN
			# STRIDE LOCK: one clip loop must advance the body by exactly one
			# cycle's worth of ground. speed_scale = speed / (distance per loop
			# / loop length) — with loop length folded in by using the clip's
			# own duration.
			scale = _stride_scale(CLIP_RUN, run_cycle_distance)
		else:
			want = CLIP_WALK
			scale = _stride_scale(CLIP_WALK, walk_cycle_distance)
	elif _talk_hold > 0.0:
		want = CLIP_TALK
		scale = 1.0

	if _talk_hold > 0.0:
		_talk_hold -= delta

	if want != _clip:
		_play(want, BLEND)
	player.speed_scale = clampf(scale, 0.25, 2.6)


func _stride_scale(clip: String, cycle_distance: float) -> float:
	var anim := player.get_animation(clip) if player != null else null
	if anim == null or cycle_distance <= 0.01:
		return 1.0
	var loop_len := maxf(anim.length, 0.05)
	# Ground speed the clip depicts at speed_scale 1.0.
	var native := cycle_distance / loop_len
	return clampf(_speed / maxf(native, 0.05), 0.25, 2.6)


func _play(clip: String, blend: float) -> void:
	if player == null or not player.has_animation(clip):
		return
	_clip = clip
	player.play(clip, blend)


## Called by the dialogue path (via look_at_node) so a standing NPC gestures
## while it is speaking rather than freezing into the idle loop.
func look_at_node(target: Node3D) -> void:
	super.look_at_node(target)
	_talk_hold = 6.0


func clear_look_target() -> void:
	super.clear_look_target()
	_talk_hold = 0.0


# -------------------------------------------------------- head, eyes, blink

func _drive_head(delta: float) -> void:
	_blink(delta)
	if _override == null:
		return

	var want_weight := 0.0
	if look_target != null and is_instance_valid(look_target):
		_override.look_point = look_target.global_position + Vector3(0, 1.15, 0)
		want_weight = 1.0
	_look_weight = lerpf(_look_weight, want_weight, clampf(delta * 4.0, 0.0, 1.0))
	_override.look_weight = _look_weight

	# Idle drift when nobody is being looked at, plus a lead into turns.
	var drift_yaw := sin(_t * 0.31 + seed_offset * 3.0) * 0.16 * (1.0 - _gait)
	drift_yaw += clampf(_yaw_rate, -2.0, 2.0) * 0.10 * _gait
	var drift_pitch := sin(_t * 0.23 + seed_offset) * 0.05 * (1.0 - _gait)
	_override.head_offset = Vector3(drift_pitch, drift_yaw, 0.0) * (1.0 - _look_weight)
	_override.blink = _blink_amount()


## The base class writes the blink straight onto eye NODES; the skinned figure
## has eye BONES instead, so expose the current amount and let the modifier
## apply it.
func _blink_amount() -> float:
	if _blink_phase <= 0.0:
		return 0.0
	return sin(clampf(1.0 - _blink_phase, 0.0, 1.0) * PI)


func _blink(delta: float) -> void:
	if _blink_phase > 0.0:
		_blink_phase = maxf(0.0, _blink_phase - delta * 7.5)
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_phase = 1.0
		_blink_t = randf_range(1.8, 6.0)


## A short "perk" acknowledgement. With a skeleton this is a nod rather than a
## translation of the whole body.
func nudge(strength: float = 0.07) -> void:
	_impulse = maxf(_impulse, strength)
	if _override != null:
		var tw := create_tween()
		tw.tween_method(_nod, 0.0, 1.0, 0.18)
		tw.tween_method(_nod, 1.0, 0.0, 0.26)


func _nod(a: float) -> void:
	if _override != null:
		_override.head_offset.x -= a * 0.10

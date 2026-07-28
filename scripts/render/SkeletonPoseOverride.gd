extends SkeletonModifier3D
class_name SkeletonPoseOverride
## Additive bone-pose layer for the skinned pilgrim: head look-at and blinking.
##
## WHY A MODIFIER AND NOT `set_bone_pose_rotation()` IN `_process`
## ---------------------------------------------------------------
## An AnimationPlayer writes every bone pose it owns each frame. Anything that
## pokes `Skeleton3D.set_bone_pose_*` from an ordinary `_process` is racing that
## write and will flicker (or be silently overwritten) depending on node order.
## `SkeletonModifier3D._process_modification()` is the one hook Godot guarantees
## runs AFTER the animation has been applied and BEFORE the skin is computed —
## which is exactly where "keep the head pointed at whoever is speaking" and
## "close the eyelids for 130 ms" belong.
##
## Everything here is driven by plain properties that SkinnedAnimator sets; the
## modifier itself holds no policy.

## World-space point the head should look at (Vector3.INF disables).
var look_point: Vector3 = Vector3.INF
## 0..1 how strongly to apply the look (fades in/out).
var look_weight: float = 0.0
## 0 = eyes open, 1 = fully closed.
var blink: float = 0.0
## Extra additive head rotation (radians) for idle drift / nods.
var head_offset: Vector3 = Vector3.ZERO

const YAW_LIMIT := 1.0      # ~57 deg before the neck takes over
const PITCH_LIMIT := 0.5
const NECK_SHARE := 0.35    # fraction of the turn the neck contributes

var _head := -1
var _neck := -1
var _eye_l := -1
var _eye_r := -1
var _resolved := false


func _resolve() -> void:
	_resolved = true
	var sk := get_skeleton()
	if sk == null:
		return
	_head = sk.find_bone("Head")
	_neck = sk.find_bone("Neck")
	_eye_l = sk.find_bone("EyeL")
	_eye_r = sk.find_bone("EyeR")


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _resolved:
		_resolve()

	# ---- blink: squash the eye bones vertically -------------------------
	if blink > 0.001:
		var sy := maxf(0.05, 1.0 - blink * 0.94)
		if _eye_l >= 0:
			sk.set_bone_pose_scale(_eye_l, Vector3(1.0, sy, 1.0))
		if _eye_r >= 0:
			sk.set_bone_pose_scale(_eye_r, Vector3(1.0, sy, 1.0))
	else:
		if _eye_l >= 0:
			sk.set_bone_pose_scale(_eye_l, Vector3.ONE)
		if _eye_r >= 0:
			sk.set_bone_pose_scale(_eye_r, Vector3.ONE)

	if _head < 0:
		return

	var yaw := head_offset.y
	var pitch := head_offset.x
	var roll := head_offset.z

	if look_weight > 0.001 and look_point.x < INF:
		# Work in the head's PARENT space so the limits are measured against
		# the body's own facing rather than the world.
		var parent_bone := sk.get_bone_parent(_head)
		var parent_gx := sk.global_transform
		if parent_bone >= 0:
			parent_gx = sk.global_transform * sk.get_bone_global_pose(parent_bone)
		var local: Vector3 = parent_gx.affine_inverse() * look_point
		if local.length_squared() > 0.02:
			var flat := Vector2(local.x, local.z).length()
			var want_yaw := clampf(atan2(local.x, local.z), -YAW_LIMIT, YAW_LIMIT)
			var want_pitch := clampf(-atan2(local.y, maxf(flat, 0.05)),
				-PITCH_LIMIT, PITCH_LIMIT)
			yaw += want_yaw * look_weight
			pitch += want_pitch * look_weight
			roll += -want_yaw * 0.12 * look_weight
			# Spread part of the turn into the neck so the head does not swivel
			# on a stiff column.
			if _neck >= 0:
				var nq := Quaternion.from_euler(
					Vector3(want_pitch * NECK_SHARE * look_weight, 0.0,
						want_yaw * 0.0))
				nq = Quaternion.from_euler(Vector3(
					want_pitch * NECK_SHARE * look_weight,
					want_yaw * NECK_SHARE * look_weight, 0.0))
				sk.set_bone_pose_rotation(_neck,
					sk.get_bone_pose_rotation(_neck) * nq)
				yaw -= want_yaw * NECK_SHARE * look_weight
				pitch -= want_pitch * NECK_SHARE * look_weight

	if absf(yaw) > 0.0001 or absf(pitch) > 0.0001 or absf(roll) > 0.0001:
		var q := Quaternion.from_euler(Vector3(pitch, yaw, roll))
		sk.set_bone_pose_rotation(_head, sk.get_bone_pose_rotation(_head) * q)

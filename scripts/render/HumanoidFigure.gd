extends RefCounted
class_name HumanoidFigure
## Builds an in-engine 3D humanoid body (head, hair, face, torso, two jointed
## arms, two articulated legs, feet, tunic or robe) from mesh primitives, tinted
## per-character by CharacterPalette so the cast read as real 3D people instead
## of flat painted billboards. Returns a Node3D root whose feet sit on the
## ground (y = 0).
##
## 2026 fidelity pass — what changed and why:
##
##  1. SUBDIVISION IS NOW EXPLICIT AND TIER-AWARE. Godot's default SphereMesh is
##     64x32 (~4k tris); the old figure spent ~4k tris on EACH EYEBALL and came
##     to ~32k tris per person, x42 NPCs in a chapter. Every primitive now sets
##     radial/rings through QualityTier.segments(), so a figure costs ~3.5k tris
##     on desktop and ~2k on web — a 9x cut that buys the extra anatomy below.
##
##  2. SHARED MATERIALS. Materials are cached by (colour, roughness, foe) so a
##     crowd of pilgrims in the same palette shares one material instead of
##     allocating 20 per body.
##
##  3. REAL JOINTS. Arms are now shoulder -> upper arm -> ELBOW -> forearm ->
##     hand, and legs gained an ANKLE pivot. The animator can fold the elbow on
##     the forward swing and roll the foot through heel-strike / toe-off, which
##     is most of the difference between "walking" and "sliding".
##
##  4. AN ANIMATABLE HEAD. The head, face and hair hang off a HeadPivot instead
##     of being welded to the torso, so the animator can turn/tilt the head to
##     look at whoever is speaking, and blink.
##
##  5. A FACE THAT READS. Eyes are proper lens-shaped spheres with separate
##     eyelids (scaled to blink), plus brows and a mouth line. At gameplay
##     camera distance this is the difference between a person and a mannequin.
##
##  6. RIM LIGHT ON EVERY SURFACE. A rim term separates the figure from the
##     background in the dark chapters (Valley of the Shadow, Doubting Castle)
##     and survives the gl_compatibility renderer, where SSAO does not.
##
##  7. BUILD VARIATION. Height, shoulder width and stance are jittered by a hash
##     of the character's name, so a crowd stops looking like one mesh cloned.
##
## Call sites pass the character's NAME (which they already know) rather than a
## flat texture. The public signature is unchanged.

## Named child nodes other systems may look up on the returned root.
const N_BODY := "Body"
const N_HEAD := "HeadPivot"
const N_CHEST := "Chest"

static var _mat_cache: Dictionary = {}


## Build a humanoid. `name` selects the palette; `height` is the figure's total
## height in metres (top of head); `mover` is the Node3D whose world motion
## drives the walk (null => standing idle); `tint` seeds un-tabled NPCs; set
## `is_foe` for the menacing emissive look.
static func make(name: String, height: float = 2.0, mover: Node3D = null,
		with_shadow: bool = true, tint: Color = Color(1, 1, 1), is_foe: bool = false) -> Node3D:
	var pal := CharacterPalette.for_name(name, tint, is_foe)
	var foe := bool(pal.get("is_foe", false))
	var long_robe := bool(pal.get("long_robe", false))

	# --- per-character build variation (deterministic from the name) ---
	var seed_v := int(abs(hash(name)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var build := 1.0 + rng.randf_range(-0.055, 0.055)      # overall height nudge
	var breadth := 1.0 + rng.randf_range(-0.09, 0.11)      # shoulder width
	var stance := rng.randf_range(0.92, 1.08)              # hip spacing
	var head_sz := 1.0 + rng.randf_range(-0.05, 0.05)
	var s := (height * build) / 2.0  # unit skeleton is ~2.0 m tall

	var skin_m := _mat(pal["skin"], 0.62, foe, 0.30)
	var robe_m := _mat(pal["robe"], 0.92, foe, 0.34)
	var robe2_m := _mat(pal["robe2"], 0.92, foe, 0.30)
	var hair_m := _mat(pal["hair"], 0.78, foe, 0.36)
	var accent_m := _mat(pal["accent"], 0.55, foe, 0.40)
	var hose_m := _mat((pal["robe2"] as Color).darkened(0.08), 0.9, foe, 0.28)
	var boot_m := _mat((pal["robe2"] as Color).darkened(0.5), 0.72, foe, 0.30)
	var eye_white_m := _mat(Color(0.9, 0.89, 0.86), 0.28, false, 0.2)
	var eye_m := _mat(Color(0.11, 0.09, 0.07), 0.32, foe, 0.2)
	var lip_m := _mat((pal["skin"] as Color).darkened(0.34), 0.6, foe, 0.2)

	# ---- vertical landmarks (unit skeleton, * s) ----
	var hip_y := 0.98 * s
	var knee_y := 0.52 * s
	var ankle_y := 0.10 * s
	var shoulder_y := 1.58 * s
	var head_y := 1.83 * s
	var head_r := 0.16 * s * head_sz
	var thigh_len := hip_y - knee_y
	var shin_len := knee_y - ankle_y
	var upper_arm := 0.36 * s
	var fore_arm := 0.34 * s

	var root := Node3D.new()
	root.name = "Humanoid"

	var body := Node3D.new()  # everything that bobs / leans during the walk
	body.name = N_BODY
	root.add_child(body)

	# Pelvis
	var hips := _mi(_box(Vector3(0.36 * breadth, 0.24, 0.26) * s), robe2_m,
		Vector3(0, hip_y + 0.02 * s, 0), "Hips")
	body.add_child(hips)

	# Torso — parented to a Chest node so the animator can breathe it.
	var chest := Node3D.new()
	chest.name = N_CHEST
	chest.position = Vector3(0, hip_y, 0)
	body.add_child(chest)

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.19 * s * lerpf(1.0, breadth, 0.6)
	torso_mesh.height = 0.7 * s
	torso_mesh.radial_segments = QualityTier.segments(16, 8)
	torso_mesh.rings = QualityTier.segments(6, 3)
	var torso := _mi(torso_mesh, robe_m, Vector3(0, (shoulder_y - hip_y) * 0.5, 0), "Torso")
	chest.add_child(torso)

	# Shoulder breadth
	var shoulders := _mi(_box(Vector3(0.52 * breadth, 0.2, 0.26) * s), robe_m,
		Vector3(0, shoulder_y - hip_y, 0), "Shoulders")
	chest.add_child(shoulders)

	# Neck
	var neck := _mi(_cyl(0.075 * s, 0.085 * s, 0.13 * s), skin_m,
		Vector3(0, shoulder_y - hip_y + 0.1 * s, 0), "Neck")
	chest.add_child(neck)

	# ---- HEAD PIVOT: head + face + hair, so the animator can look around ----
	var head_pivot := Node3D.new()
	head_pivot.name = N_HEAD
	head_pivot.position = Vector3(0, head_y - hip_y, 0)
	chest.add_child(head_pivot)

	var head := _mi(_sphere(head_r), skin_m, Vector3.ZERO, "Head")
	head.scale = Vector3(0.94, 1.06, 0.98)   # a skull, not a ball
	head_pivot.add_child(head)

	# Jaw — widens the lower face so the head silhouette reads as a head.
	var jaw := _mi(_box(Vector3(head_r * 1.26, head_r * 0.62, head_r * 1.2)), skin_m,
		Vector3(0, -head_r * 0.5, head_r * 0.06), "Jaw")
	head_pivot.add_child(jaw)

	# Face: eye whites + irises on separate lid nodes (blink = scale.y).
	for side in [-1.0, 1.0]:
		var lid := Node3D.new()
		lid.name = "EyeL" if side < 0.0 else "EyeR"
		lid.position = Vector3(side * head_r * 0.40, head_r * 0.10, head_r * 0.80)
		head_pivot.add_child(lid)
		var white := _mi(_sphere(head_r * 0.20), eye_white_m, Vector3.ZERO, "White")
		white.scale = Vector3(1.0, 0.72, 0.55)
		lid.add_child(white)
		var iris := _mi(_sphere(head_r * 0.105), eye_m, Vector3(0, 0, head_r * 0.11), "Iris")
		iris.scale = Vector3(1.0, 1.0, 0.6)
		lid.add_child(iris)

	if QualityTier.character_extras():
		# Brows and a mouth line — tiny geometry, disproportionate readability.
		for side2 in [-1.0, 1.0]:
			var brow := _mi(_box(Vector3(head_r * 0.42, head_r * 0.09, head_r * 0.12)), hair_m,
				Vector3(side2 * head_r * 0.40, head_r * 0.36, head_r * 0.80), "Brow")
			brow.rotation.z = -side2 * 0.14
			head_pivot.add_child(brow)
		var mouth := _mi(_box(Vector3(head_r * 0.42, head_r * 0.08, head_r * 0.1)), lip_m,
			Vector3(0, -head_r * 0.44, head_r * 0.74), "Mouth")
		head_pivot.add_child(mouth)
		var nose := _mi(_box(Vector3(head_r * 0.16, head_r * 0.26, head_r * 0.18)), skin_m,
			Vector3(0, -head_r * 0.08, head_r * 0.88), "Nose")
		head_pivot.add_child(nose)

	# Hair: a flattened cap raised onto the crown and pushed back, so the face
	# (front) stays bare skin and the figure visibly faces +Z.
	var hair := _mi(_sphere(head_r * 1.06), hair_m, Vector3(0, head_r * 0.30, -head_r * 0.22), "Hair")
	hair.scale = Vector3(1.02, 0.76, 1.04)
	head_pivot.add_child(hair)

	# Legs (hip -> thigh -> knee -> shin -> ankle -> foot).
	var hip_dx := 0.11 * s * stance
	var leg_l := _make_leg(body, -hip_dx, hip_y, thigh_len, shin_len, 0.115 * s, hose_m, boot_m, s)
	var leg_r := _make_leg(body, hip_dx, hip_y, thigh_len, shin_len, 0.115 * s, hose_m, boot_m, s)

	# Arms (shoulder -> upper -> elbow -> forearm -> hand).
	var arm_dx := 0.25 * s * breadth
	var arm_l := _make_arm(chest, -arm_dx, shoulder_y - hip_y, upper_arm, fore_arm, 0.07 * s, robe_m, skin_m, s)
	var arm_r := _make_arm(chest, arm_dx, shoulder_y - hip_y, upper_arm, fore_arm, 0.07 * s, robe_m, skin_m, s)
	var arm_l_pivot := arm_l[0] as Node3D
	var arm_r_pivot := arm_r[0] as Node3D
	arm_l_pivot.name = "ArmL"
	arm_r_pivot.name = "ArmR"

	# Garment over the legs, on a Hem node so the animator can swing the cloth.
	var hem := Node3D.new()
	hem.name = "Hem"
	body.add_child(hem)
	if long_robe:
		var rm := _cyl(0.22 * s, 0.44 * s, hip_y + 0.14 * s - 0.1 * s)
		var robe := _mi(rm, robe_m, Vector3(0, (hip_y + 0.14 * s + 0.1 * s) * 0.5, 0), "Robe")
		hem.add_child(robe)
	else:
		var tm := _cyl(0.21 * s, 0.3 * s, 0.52 * s)
		var tunic := _mi(tm, robe_m, Vector3(0, 0.92 * s, 0), "Tunic")
		hem.add_child(tunic)
		var bm := _cyl(0.215 * s, 0.215 * s, 0.06 * s)
		var belt := _mi(bm, accent_m, Vector3(0, hip_y + 0.08 * s, 0), "Belt")
		body.add_child(belt)

	# Animator: walk cycle for movers, idle sway for the rest, + contact shadow.
	var anim := HumanoidAnimator.new()
	anim.body = body
	anim.chest = chest
	anim.head = head_pivot
	anim.eye_l = head_pivot.get_node_or_null("EyeL") as Node3D
	anim.eye_r = head_pivot.get_node_or_null("EyeR") as Node3D
	anim.hem = hem
	anim.hip_l = leg_l[0] as Node3D
	anim.hip_r = leg_r[0] as Node3D
	anim.knee_l = leg_l[1] as Node3D
	anim.knee_r = leg_r[1] as Node3D
	anim.ankle_l = leg_l[2] as Node3D
	anim.ankle_r = leg_r[2] as Node3D
	anim.arm_l = arm_l_pivot
	anim.arm_r = arm_r_pivot
	anim.elbow_l = arm_l[1] as Node3D
	anim.elbow_r = arm_r[1] as Node3D
	anim.mover = mover
	anim.make_shadow = with_shadow
	anim.shadow_width = 0.62 * s
	anim.height_scale = s
	anim.step_length = 0.86 * s
	anim.seed_offset = float(seed_v % 997) * 0.0063
	root.add_child(anim)

	if not QualityTier.allow_character_shadows():
		_disable_shadows(root)
	return root


## One leg: hip pivot (fore/aft swing) -> thigh -> knee pivot (bend) -> shin ->
## ANKLE pivot (heel-strike / toe-off roll) -> foot.
## Returns [hip_pivot, knee_pivot, ankle_pivot].
static func _make_leg(parent: Node3D, x: float, hip_y: float, thigh_len: float,
		shin_len: float, leg_r: float, hose_m: StandardMaterial3D,
		boot_m: StandardMaterial3D, s: float) -> Array:
	var hip := Node3D.new()
	hip.position = Vector3(x, hip_y, 0)
	parent.add_child(hip)

	var thigh := _mi(_cyl(leg_r, leg_r * 0.85, thigh_len), hose_m,
		Vector3(0, -thigh_len * 0.5, 0), "Thigh")
	hip.add_child(thigh)

	var knee := Node3D.new()
	knee.position = Vector3(0, -thigh_len, 0)
	hip.add_child(knee)

	# A knee cap keeps the joint from reading as a gap when the leg folds.
	var cap := _mi(_sphere(leg_r * 0.92), hose_m, Vector3.ZERO, "KneeCap")
	knee.add_child(cap)

	var shin := _mi(_cyl(leg_r * 0.82, leg_r * 0.6, shin_len), hose_m,
		Vector3(0, -shin_len * 0.5, 0), "Shin")
	knee.add_child(shin)

	var ankle := Node3D.new()
	ankle.name = "Ankle"
	ankle.position = Vector3(0, -shin_len, 0)
	knee.add_child(ankle)

	var foot := _mi(_box(Vector3(0.15, 0.09, 0.3) * s), boot_m,
		Vector3(0, 0.045 * s, 0.07 * s), "Foot")
	ankle.add_child(foot)
	var toe := _mi(_box(Vector3(0.13, 0.07, 0.1) * s), boot_m,
		Vector3(0, 0.035 * s, 0.2 * s), "Toe")
	ankle.add_child(toe)

	return [hip, knee, ankle]


## One arm as shoulder pivot -> upper arm -> ELBOW pivot -> forearm + hand.
## Returns [shoulder_pivot, elbow_pivot].
static func _make_arm(parent: Node3D, x: float, shoulder_y: float, upper_len: float,
		fore_len: float, arm_r: float, sleeve_m: StandardMaterial3D,
		skin_m: StandardMaterial3D, s: float) -> Array:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, shoulder_y, 0)
	parent.add_child(pivot)

	var shoulder_cap := _mi(_sphere(arm_r * 1.15), sleeve_m, Vector3.ZERO, "ShoulderCap")
	pivot.add_child(shoulder_cap)

	var upper := _mi(_cyl(arm_r, arm_r * 0.9, upper_len), sleeve_m,
		Vector3(0, -upper_len * 0.5, 0), "UpperArm")
	pivot.add_child(upper)

	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -upper_len, 0)
	pivot.add_child(elbow)

	var elbow_cap := _mi(_sphere(arm_r * 0.88), sleeve_m, Vector3.ZERO, "ElbowCap")
	elbow.add_child(elbow_cap)

	var fore := _mi(_cyl(arm_r * 0.86, arm_r * 0.72, fore_len), skin_m,
		Vector3(0, -fore_len * 0.5, 0), "Forearm")
	elbow.add_child(fore)

	var hand := _mi(_sphere(arm_r * 1.15), skin_m, Vector3(0, -fore_len, 0), "Hand")
	hand.scale = Vector3(0.8, 1.15, 0.62)
	elbow.add_child(hand)

	if QualityTier.character_extras():
		# A thumb block turns the sphere into something hand-shaped in silhouette.
		var thumb := _mi(_box(Vector3(arm_r * 0.5, arm_r * 0.9, arm_r * 0.5)), skin_m,
			Vector3(arm_r * 0.7, -fore_len + arm_r * 0.35, 0), "Thumb")
		elbow.add_child(thumb)

	return [pivot, elbow]


# ------------------------------------------------------------------ primitives
# Every primitive sets its own subdivision. Godot's defaults (sphere 64x32,
# cylinder 64) are wildly over-tessellated for figures that are 40 px tall on
# screen; QualityTier.segments() scales them per render tier.

static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = QualityTier.segments(16, 8)
	m.rings = QualityTier.segments(8, 4)
	return m


static func _cyl(top_r: float, bot_r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = QualityTier.segments(12, 6)
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _mi(mesh: Mesh, mat: Material, pos: Vector3, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.name = node_name
	return mi


static func _disable_shadows(root: Node) -> void:
	for c in root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disable_shadows(c)


## Cached StandardMaterial3D. A crowd in the same palette now shares materials
## instead of allocating ~20 per body, which cuts state changes on the web build.
## `rim` adds a view-dependent edge light that separates the figure from dark
## backgrounds — it works on gl_compatibility, unlike SSAO.
static func _mat(c: Color, rough: float, foe: bool = false, rim: float = 0.3) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [c.to_html(true), rough, str(foe), rim]
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.2
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.45
	if foe:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.45
		m.rim = maxf(rim, 0.5)
	_mat_cache[key] = m
	return m


## Drop the shared-material cache (call on a full scene reload if palettes were
## changed at runtime; harmless otherwise).
static func clear_cache() -> void:
	_mat_cache.clear()

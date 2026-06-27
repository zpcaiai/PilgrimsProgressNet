extends RefCounted
class_name HumanoidFigure
## Builds an in-engine 3D humanoid body (head, hair, torso, two arms, two
## articulated legs with knees, feet, tunic or robe) from mesh primitives,
## tinted per-character by CharacterPalette so the cast read as real 3D people
## instead of flat painted billboards. Returns a Node3D root whose feet sit on
## the ground (y = 0).
##
## Proportions follow a roughly realistic adult figure (~6.5 heads tall, legs
## about half the total height). Each leg is hip -> thigh -> KNEE -> shin ->
## foot, so HumanoidAnimator can bend the knee on the swing leg and the walk
## reads as real walking rather than two stiff poles sliding along.
##
## A HumanoidAnimator child drives the motion: movers (player / companion /
## enemy) get a bipedal WALK CYCLE; standing NPCs get a gentle idle sway. The
## animator also drops a soft contact shadow.
##
## Call sites pass the character's NAME (which they already know) rather than a
## flat texture.

## Build a humanoid. `name` selects the palette; `height` is the figure's total
## height in metres (top of head); `mover` is the Node3D whose world motion
## drives the walk (null => standing idle); `tint` seeds un-tabled NPCs; set
## `is_foe` for the menacing emissive look.
static func make(name: String, height: float = 2.0, mover: Node3D = null,
		with_shadow: bool = true, tint: Color = Color(1, 1, 1), is_foe: bool = false) -> Node3D:
	var pal := CharacterPalette.for_name(name, tint, is_foe)
	var foe := bool(pal.get("is_foe", false))
	var long_robe := bool(pal.get("long_robe", false))
	var s := height / 2.0  # unit skeleton is ~2.0 m tall; scale everything by s

	var skin_m := _mat(pal["skin"], 0.78, foe)
	var robe_m := _mat(pal["robe"], 0.95, foe)
	var robe2_m := _mat(pal["robe2"], 0.95, foe)
	var hair_m := _mat(pal["hair"], 0.85, foe)
	var accent_m := _mat(pal["accent"], 0.7, foe)
	var hose_m := _mat((pal["robe2"] as Color).darkened(0.08), 0.9, foe)
	var boot_m := _mat((pal["robe2"] as Color).darkened(0.5), 0.8, foe)

	# ---- vertical landmarks (unit skeleton, * s) ----
	var hip_y := 0.98 * s        # crotch / hip pivot — legs are ~half the height
	var knee_y := 0.52 * s
	var ankle_y := 0.08 * s
	var shoulder_y := 1.58 * s
	var head_y := 1.83 * s
	var head_r := 0.16 * s
	var thigh_len := hip_y - knee_y
	var shin_len := knee_y - ankle_y
	var arm_len := 0.72 * s

	var root := Node3D.new()
	root.name = "Humanoid"

	var body := Node3D.new()  # everything that bobs / leans during the walk
	body.name = "Body"
	root.add_child(body)

	# Pelvis
	var hips := MeshInstance3D.new()
	var hips_m := BoxMesh.new()
	hips_m.size = Vector3(0.36, 0.24, 0.26) * s
	hips.mesh = hips_m
	hips.position = Vector3(0, hip_y + 0.02 * s, 0)
	hips.material_override = robe2_m
	body.add_child(hips)

	# Torso
	var torso := MeshInstance3D.new()
	var torso_m := CapsuleMesh.new()
	torso_m.radius = 0.19 * s
	torso_m.height = 0.7 * s
	torso.mesh = torso_m
	torso.position = Vector3(0, (hip_y + shoulder_y) * 0.5, 0)
	torso.material_override = robe_m
	body.add_child(torso)

	# Shoulder breadth
	var shoulders := MeshInstance3D.new()
	var sh_m := BoxMesh.new()
	sh_m.size = Vector3(0.52, 0.2, 0.26) * s
	shoulders.mesh = sh_m
	shoulders.position = Vector3(0, shoulder_y, 0)
	shoulders.material_override = robe_m
	body.add_child(shoulders)

	# Neck
	var neck := MeshInstance3D.new()
	var neck_m := CylinderMesh.new()
	neck_m.top_radius = 0.075 * s
	neck_m.bottom_radius = 0.085 * s
	neck_m.height = 0.13 * s
	neck.mesh = neck_m
	neck.position = Vector3(0, shoulder_y + 0.1 * s, 0)
	neck.material_override = skin_m
	body.add_child(neck)

	# Head
	var head := MeshInstance3D.new()
	var hd_m := SphereMesh.new()
	hd_m.radius = head_r
	hd_m.height = head_r * 2.0
	head.mesh = hd_m
	head.position = Vector3(0, head_y, 0)
	head.material_override = skin_m
	body.add_child(head)

	# Eyes — two small spheres on the face (front, +Z) so the cast read as people
	# rather than blank heads. (Foes get the menacing emissive look via _mat.)
	var eye_m := _mat(Color(0.12, 0.1, 0.08), 0.4, foe)
	for ex in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = head_r * 0.17
		em.height = head_r * 0.34
		eye.mesh = em
		eye.position = Vector3(ex * head_r * 0.42, head_y + head_r * 0.12, head_r * 0.82)
		eye.material_override = eye_m
		body.add_child(eye)

	# Hair: a flattened cap raised onto the crown and pushed back, so the face
	# (front) stays bare skin and the figure visibly faces +Z.
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = head_r * 1.05
	hair_mesh.height = head_r * 2.0 * 1.05
	hair.mesh = hair_mesh
	hair.scale = Vector3(1.0, 0.74, 1.0)
	hair.position = Vector3(0, head_y + 0.06 * s, -0.04 * s)
	hair.material_override = hair_m
	body.add_child(hair)

	# Legs (hip -> thigh -> knee -> shin -> foot). Always built so the walk
	# animator has joints; hidden under a long robe except for shins/feet that
	# peek beneath the hem.
	var hip_dx := 0.11 * s
	var leg_l := _make_leg(body, -hip_dx, hip_y, thigh_len, shin_len, 0.115 * s, hose_m, boot_m, s)
	var leg_r := _make_leg(body, hip_dx, hip_y, thigh_len, shin_len, 0.115 * s, hose_m, boot_m, s)

	# Arms
	var arm_dx := 0.25 * s
	var arm_l := _make_arm(body, -arm_dx, shoulder_y, arm_len, 0.07 * s, robe_m, skin_m, s)
	var arm_r := _make_arm(body, arm_dx, shoulder_y, arm_len, 0.07 * s, robe_m, skin_m, s)
	arm_l.name = "ArmL"
	arm_r.name = "ArmR"

	# Garment over the legs: a long conical robe for standing NPCs, or a short
	# belted tunic (knees + shins visible below the hem) for the travelling
	# pilgrims who walk.
	if long_robe:
		var robe := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.22 * s
		rm.bottom_radius = 0.44 * s
		rm.height = hip_y + 0.14 * s - 0.1 * s
		robe.mesh = rm
		robe.position = Vector3(0, (hip_y + 0.14 * s + 0.1 * s) * 0.5, 0)
		robe.material_override = robe_m
		body.add_child(robe)
	else:
		var tunic := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.21 * s
		tm.bottom_radius = 0.3 * s
		tm.height = 0.52 * s
		tunic.mesh = tm
		tunic.position = Vector3(0, 0.92 * s, 0)  # hem ~0.66 s, above the knee
		tunic.material_override = robe_m
		body.add_child(tunic)
		var belt := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.215 * s
		bm.bottom_radius = 0.215 * s
		bm.height = 0.06 * s
		belt.mesh = bm
		belt.position = Vector3(0, hip_y + 0.08 * s, 0)
		belt.material_override = accent_m
		body.add_child(belt)

	# Animator: walk cycle for movers, idle sway for the rest, + contact shadow.
	var anim := HumanoidAnimator.new()
	anim.body = body
	anim.hip_l = leg_l[0] as Node3D
	anim.hip_r = leg_r[0] as Node3D
	anim.knee_l = leg_l[1] as Node3D
	anim.knee_r = leg_r[1] as Node3D
	anim.arm_l = arm_l
	anim.arm_r = arm_r
	anim.mover = mover
	anim.make_shadow = with_shadow
	anim.shadow_width = 0.62 * s
	anim.height_scale = s
	root.add_child(anim)
	return root


## One leg: a hip pivot (fore/aft swing) -> thigh -> knee pivot (bend) -> shin ->
## foot. Returns [hip_pivot, knee_pivot] for the animator to rotate.
static func _make_leg(parent: Node3D, x: float, hip_y: float, thigh_len: float,
		shin_len: float, leg_r: float, hose_m: StandardMaterial3D,
		boot_m: StandardMaterial3D, s: float) -> Array:
	var hip := Node3D.new()
	hip.position = Vector3(x, hip_y, 0)
	parent.add_child(hip)

	var thigh := MeshInstance3D.new()
	var thm := CylinderMesh.new()
	thm.top_radius = leg_r
	thm.bottom_radius = leg_r * 0.85
	thm.height = thigh_len
	thigh.mesh = thm
	thigh.position = Vector3(0, -thigh_len * 0.5, 0)
	thigh.material_override = hose_m
	hip.add_child(thigh)

	var knee := Node3D.new()
	knee.position = Vector3(0, -thigh_len, 0)
	hip.add_child(knee)

	var shin := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = leg_r * 0.82
	shm.bottom_radius = leg_r * 0.6
	shm.height = shin_len
	shin.mesh = shm
	shin.position = Vector3(0, -shin_len * 0.5, 0)
	shin.material_override = hose_m
	knee.add_child(shin)

	var foot := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.15, 0.09, 0.3) * s
	foot.mesh = fm
	foot.position = Vector3(0, -shin_len + 0.045 * s, 0.07 * s)
	foot.material_override = boot_m
	knee.add_child(foot)

	return [hip, knee]


## One arm as a shoulder pivot (rotated by the animator) with a sleeve + hand.
static func _make_arm(parent: Node3D, x: float, shoulder_y: float, arm_len: float,
		arm_r: float, sleeve_m: StandardMaterial3D, skin_m: StandardMaterial3D, s: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, shoulder_y, 0)
	parent.add_child(pivot)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = arm_r
	am.bottom_radius = arm_r * 0.8
	am.height = arm_len
	arm.mesh = am
	arm.position = Vector3(0, -arm_len * 0.5, 0)
	arm.material_override = sleeve_m
	pivot.add_child(arm)
	var hand := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = arm_r * 1.25
	hm.height = arm_r * 2.5
	hand.mesh = hm
	hand.position = Vector3(0, -arm_len, 0)
	hand.material_override = skin_m
	pivot.add_child(hand)
	return pivot


static func _mat(c: Color, rough: float, foe: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.18
	if foe:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.45
	return m

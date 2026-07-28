extends RefCounted
class_name SkinnedFigure
## Instantiates the SKINNED character (assets/characters/rig/pilgrim.glb) and
## re-tints it per character, so one rigged model serves the whole cast.
##
## This is the batch-2 replacement for HumanoidFigure's ~20 rigid primitives.
## What it buys, concretely:
##
##   * DEFORMATION. Shoulders, hips, elbows and knees are skinned across bone
##     boundaries, so a bent arm is a bent arm instead of two cylinders meeting
##     at a visible seam.
##   * CLOTH THAT FOLLOWS. The tunic is weighted to Hips + both Thighs, so it
##     swings with the stride instead of being a rigid cone bolted to the waist.
##   * A FACE WITH BONES. Head / Jaw / EyeL / EyeR are real bones, so look-at,
##     blinking and jaw motion during speech are pose data, not node hacks.
##   * ONE DRAW CALL PER MATERIAL instead of per body part: 7 surfaces on one
##     skinned mesh, versus 20 MeshInstance3Ds.
##
## The public API mirrors HumanoidFigure.make() exactly, so FigureFactory can
## swap between them with no call-site changes.

const MODEL_PATH := "res://assets/characters/rig/pilgrim.glb"

## Material name in the GLB -> CharacterPalette key.
const SLOT_TO_PALETTE := {
	"Skin": "skin",
	"Robe": "robe",
	"Robe2": "robe2",
	"Hair": "hair",
	"Accent": "accent",
	"Boot": "robe2",
}

## The rig is authored at this height; everything scales from it.
const RIG_HEIGHT := 2.0

static var _packed: PackedScene = null
static var _checked := false


## True when the rigged model is present and importable.
static func available() -> bool:
	if not _checked:
		_checked = true
		if ResourceLoader.exists(MODEL_PATH):
			_packed = load(MODEL_PATH) as PackedScene
	return _packed != null


## Same signature as HumanoidFigure.make(). Returns null if the model is
## missing, so the caller can fall back.
static func make(name: String, height: float = 2.0, mover: Node3D = null,
		with_shadow: bool = true, tint: Color = Color(1, 1, 1),
		is_foe: bool = false) -> Node3D:
	if not available():
		return null
	var inst := _packed.instantiate() as Node3D
	if inst == null:
		return null

	var root := Node3D.new()
	root.name = "Humanoid"
	root.add_child(inst)

	# --- per-character build variation, matching the primitive figure --------
	var seed_v := int(abs(hash(name)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var build := 1.0 + rng.randf_range(-0.055, 0.055)
	var breadth := 1.0 + rng.randf_range(-0.05, 0.06)
	var s := (height * build) / RIG_HEIGHT
	inst.scale = Vector3(s * breadth, s, s)

	var skel := _find_skeleton(inst)
	var player := _find_player(inst)
	var mesh := _find_mesh(inst)

	_tint(mesh, name, tint, is_foe)

	var anim := SkinnedAnimator.new()
	anim.name = "SkinnedAnimator"
	anim.model_root = inst
	anim.skeleton = skel
	anim.player = player
	anim.body = inst              # so the base class can read the parent's yaw
	anim.mover = mover
	anim.make_shadow = with_shadow
	anim.shadow_width = 0.62 * s
	anim.height_scale = s
	anim.step_length = 0.86 * s
	anim.walk_cycle_distance = 1.72 * s
	anim.run_cycle_distance = 2.35 * s
	anim.seed_offset = float(seed_v % 997) * 0.0063
	root.add_child(anim)

	if not QualityTier.allow_character_shadows() and mesh != null:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


# ---------------------------------------------------------------- internals

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f := _find_skeleton(c)
		if f != null:
			return f
	return null


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var f := _find_player(c)
		if f != null:
			return f
	return null


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var f := _find_mesh(c)
		if f != null:
			return f
	return null


## Re-colour the model's surfaces from CharacterPalette. Surfaces are matched by
## MATERIAL NAME (Skin / Robe / Robe2 / Hair / Accent / Eye / Boot), which is
## also the contract a hand-made replacement model has to honour. Unknown
## material names are left untouched rather than guessed at.
static func _tint(mesh: MeshInstance3D, name: String, tint: Color, is_foe: bool) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var pal := CharacterPalette.for_name(name, tint, is_foe)
	var foe := bool(pal.get("is_foe", false))
	for si in range(mesh.mesh.get_surface_count()):
		var src: Material = mesh.mesh.surface_get_material(si)
		var mat_name := ""
		if src != null:
			mat_name = src.resource_name
		var key := String(SLOT_TO_PALETTE.get(mat_name, ""))
		var m := StandardMaterial3D.new()
		if src is StandardMaterial3D:
			m = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
		if key != "" and pal.has(key):
			var c: Color = pal[key]
			if mat_name == "Boot":
				c = c.darkened(0.5)
			elif mat_name == "Robe2":
				c = c.darkened(0.08)
			m.albedo_color = c
		# Rim light on everything, exactly as the primitive figure does — it is
		# what keeps a character readable against the dark chapters on the
		# gl_compatibility build, where there is no SSAO.
		m.rim_enabled = true
		m.rim = 0.5 if foe else 0.32
		m.rim_tint = 0.45
		if foe:
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 0.45
		mesh.set_surface_override_material(si, m)

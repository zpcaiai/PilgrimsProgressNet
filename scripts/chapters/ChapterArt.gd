extends RefCounted
class_name ChapterArt
## Bespoke "showcase" art for every chapter — the deep-polish layer, every
## chapter brought to the same flagship depth as the Celestial City.
##
## ChapterBase._apply_world_rebuild() calls build(self, id) AFTER the generic
## profile (lighting/fog/dressing), so each chapter gets a richly composed,
## multi-layer centrepiece with its own accent lighting, framing, particles and
## animated-shader touches — WITHOUT duplicating the gameplay geometry the
## chapter already builds, and with all colliding pieces kept off the walkable
## corridor (positions chosen from each chapter's ground width / spawn / exit).
##
## Reuses PropKit + MaterialKit and the animated shaders glory_gold / godray /
## water, all with graceful fallback if a shader file is missing.

const GODRAY := "res://assets/shaders/godray.gdshader"
const WATER := "res://assets/shaders/water.gdshader"


static func build(parent: Node3D, id: String) -> void:
	match id:
		"celestial_city":
			CelestialCityArt.build(parent)
		"city_of_destruction":
			_city_of_destruction(parent)
		"slough_of_despond":
			_slough(parent)
		"wicket_gate":
			_wicket_gate(parent)
		"interpreter_house":
			_interpreter(parent)
		"hill_difficulty":
			_hill(parent)
		"palace_beautiful":
			_palace(parent)
		"valley_humiliation":
			_valley_humiliation(parent)
		"valley_shadow_death":
			_valley_shadow(parent)
		"vanity_fair":
			_vanity_fair(parent)
		"doubting_castle":
			_doubting_castle(parent)
		"delectable_mountains":
			_delectable(parent)
		"enchanted_ground":
			_enchanted(parent)
		"wilderness_road":
			_wilderness(parent)
		"river_of_death":
			_river(parent)
		"cross_and_tomb":
			_cross_dawn(parent)
		_:
			pass


# ===========================================================================
# Mesh / material helpers
# ===========================================================================
static func _mi(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	return n


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cone(top_r: float, bot_r: float, h: float, segs: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.radial_segments = segs
	return c


static func _dome(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.5
	s.radial_segments = 12
	s.rings = 7
	return s


static func _emit(color: Color, energy: float, unshaded: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	# Realistic mode: keep only a fraction of the glow (fire/lava still read,
	# but "magic" emissive cities/flowers/halos calm down).
	if RenderConfig.is_realistic():
		energy *= 0.35
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


# ===========================================================================
# Lighting / atmosphere helpers
# ===========================================================================
static func _accent(parent: Node3D, pos: Vector3, color: Color, energy: float, rng_dist: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng_dist
	parent.add_child(o)
	return o


static func _spot(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, angle: float = 40.0, reach: float = 80.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.position = pos
	s.light_color = color
	s.light_energy = energy
	s.spot_range = reach
	s.spot_angle = angle
	parent.add_child(s)
	s.look_at(target, Vector3.UP)
	return s


## An additive light shaft (animated godray shader, or emissive fallback).
static func _ray(parent: Node3D, pos: Vector3, height: float, top_r: float, color: Color, intensity: float, tilt_x: float = 0.0, tilt_z: float = 0.0) -> void:
	# God-ray shafts are a stylised device; realistic mode relies on real sky,
	# sun and atmosphere instead.
	if RenderConfig.is_realistic():
		return
	var mat: Material
	var sh := load(GODRAY)
	if sh is Shader:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("ray_color", Vector3(color.r, color.g, color.b))
		sm.set_shader_parameter("intensity", intensity)
		sm.set_shader_parameter("beam_height", height)
		mat = sm
	else:
		mat = _emit(color, intensity, true, 0.4)
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := _mi(_cone(top_r, 0.3, height, 14), mat, pos)
	beam.rotation_degrees = Vector3(tilt_x, 0, tilt_z)
	parent.add_child(beam)


## A soft additive billboard disc — a sun, a halo, a glow.
static func _glow_disc(parent: Node3D, pos: Vector3, radius: float, color: Color, energy: float) -> void:
	# Soft glowing suns/halos are stylised; realistic mode omits them.
	if RenderConfig.is_realistic():
		return
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var m := _emit(color, energy, true, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var spr := AssetLib.particle("soft")
	if spr != null:
		m.albedo_texture = spr
		m.emission_texture = spr
	parent.add_child(_mi(q, m, pos))


## A subdivided animated water plane (water shader, or translucent fallback).
static func _water(parent: Node3D, center: Vector3, size: Vector2, shallow: Color, deep: Color, alpha: float = 0.82) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var mat: Material
	var sh := load(WATER)
	if sh is Shader:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("shallow", Vector3(shallow.r, shallow.g, shallow.b))
		sm.set_shader_parameter("deep", Vector3(deep.r, deep.g, deep.b))
		sm.set_shader_parameter("alpha_v", alpha)
		mat = sm
	else:
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(deep.r, deep.g, deep.b, alpha)
		fm.metallic = 0.3
		fm.roughness = 0.12
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat = fm
	parent.add_child(_mi(plane, mat, center))


## Drifting glowing motes/embers over a box volume (rising).
static func _embers(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 50, rise: float = 0.4, sprite: String = "spark") -> void:
	var p := GPUParticles3D.new()
	p.position = center
	p.amount = amount
	p.lifetime = 4.0
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extents
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0.1, rise, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.7
	mat.color = color
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var dmat := _emit(color, 2.4, true, 1.0)
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spr := AssetLib.particle(sprite)
	if spr != null:
		dmat.albedo_texture = spr
		dmat.emission_texture = spr
	quad.material = dmat
	p.draw_pass_1 = quad
	parent.add_child(p)


# ===========================================================================
# Prop helpers
# ===========================================================================
static func _tower(parent: Node3D, x: float, z: float, w: float, h: float, mat: Material, spire: bool) -> void:
	parent.add_child(_mi(_box(Vector3(w, h, w)), mat, Vector3(x, h * 0.5, z)))
	if spire:
		parent.add_child(_mi(_cone(0.0, w * 0.7, w * 1.7, 8), mat, Vector3(x, h + w * 0.85, z)))
	else:
		parent.add_child(_mi(_box(Vector3(w * 1.12, 1.0, w * 1.12)), mat, Vector3(x, h + 0.5, z)))


static func _dead_tree(parent: Node3D, pos: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var bark := MaterialKit.make("bark", Color(0.2, 0.18, 0.15))
	var trunk := _mi(_cone(0.1, 0.3, h, 6), bark, pos + Vector3(0, h * 0.5, 0))
	trunk.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-12, 12))
	parent.add_child(trunk)
	for k in range(3):
		var b := _mi(_cone(0.02, 0.11, h * 0.45, 4), bark, pos + Vector3(0, h * rng.randf_range(0.6, 0.95), 0))
		b.rotation_degrees = Vector3(rng.randf_range(25, 60), rng.randf_range(0, 360), 0)
		parent.add_child(b)


## A simple distant crowd silhouette.
static func _figure(parent: Node3D, pos: Vector3, color: Color) -> void:
	parent.add_child(_mi(_cone(0.18, 0.28, 1.2, 6), MaterialKit.make("cloth", color, {"tint_blend": 0.7}), pos + Vector3(0, 0.6, 0)))
	parent.add_child(_mi(_dome(0.16), MaterialKit.make("cloth", color.lightened(0.12), {"tint_blend": 0.7}), pos + Vector3(0, 1.32, 0)))


## A string of little colour flags between two points (festive bunting).
static func _bunting(parent: Node3D, a: Vector3, b: Vector3, count: int) -> void:
	var rng := _rng(int(a.x * 7.0 + b.z * 3.0) + 1)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var pos := a.lerp(b, t)
		pos.y -= sin(t * PI) * 0.8
		var col := Color.from_hsv(rng.randf(), 0.7, 0.95)
		parent.add_child(_mi(_box(Vector3(0.35, 0.45, 0.05)), MaterialKit.make("cloth", col, {"tint_blend": 0.8}), pos))


## A stylized crouching guardian lion.
static func _lion(parent: Node3D, pos: Vector3, yaw: float, tint: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw, 0)
	var stone := MaterialKit.make("stone", tint)
	var body := _mi(_dome(0.8), stone, Vector3(0, 0.9, 0))
	body.scale = Vector3(1.8, 1.0, 1.0)
	root.add_child(body)
	root.add_child(_mi(_dome(0.5), stone, Vector3(1.1, 1.2, 0)))
	root.add_child(_mi(_box(Vector3(2.4, 0.5, 1.4)), stone, Vector3(0, 0.25, 0)))
	for lx in [-0.5, 0.6]:
		for lz in [-0.35, 0.35]:
			root.add_child(_mi(_cone(0.16, 0.18, 0.8, 6), stone, Vector3(lx, 0.4, lz)))
	parent.add_child(root)


# ===========================================================================
# Per-chapter centrepieces (flagship depth)
# ===========================================================================

## City of Destruction — the doomed city ablaze behind the fleeing pilgrim,
## a cool hope-gate ahead. Two depth layers of ruins, fire-glow pools, ember
## rain, smoke columns.
static func _city_of_destruction(parent: Node3D) -> void:
	var rng := _rng(101)
	var ash := MaterialKit.make("ash", Color(0.2, 0.17, 0.16))
	var dark := MaterialKit.make("ash", Color(0.12, 0.11, 0.12))
	# Near, detailed burning ruins (behind spawn, +Z).
	for i in range(6):
		var x := rng.randf_range(-17, 17)
		var z := rng.randf_range(15, 23)
		var h := rng.randf_range(7, 16)
		var w := rng.randf_range(2.6, 4.4)
		var t := _mi(_box(Vector3(w, h, w)), ash, Vector3(x, h * 0.5, z))
		t.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf_range(0, 30), rng.randf_range(-4, 4))
		parent.add_child(t)
		parent.add_child(_mi(_box(Vector3(w * 0.5, h * 0.5, w * 0.5)), _emit(Color(1.0, 0.45, 0.15), 2.2), Vector3(x, h * 0.4, z)))
		if rng.randf() < 0.7:
			PropKit.fire(parent, Vector3(x, h, z), rng.randf_range(0.8, 1.6), Color(1.0, 0.5, 0.18))
		PropKit.smoke(parent, Vector3(x, h + 1, z), rng.randf_range(1.6, 2.8), Color(0.1, 0.09, 0.09))
		_accent(parent, Vector3(x, 1.5, z), Color(1.0, 0.4, 0.12), rng.randf_range(2.0, 4.0), 14.0)
	# Far silhouette skyline.
	for i in range(7):
		_tower(parent, rng.randf_range(-22, 22), rng.randf_range(26, 36), rng.randf_range(2.5, 4.5), rng.randf_range(8, 20), dark, false)
	_embers(parent, Vector3(0, 9, 22), Vector3(20, 8, 12), Color(1.0, 0.55, 0.2), 70)
	# Hope ahead.
	_ray(parent, Vector3(0, 11, -32), 18, 4, Color(1.0, 0.95, 0.78), 0.9)
	_glow_disc(parent, Vector3(0, 6, -34), 6.0, Color(1.0, 0.95, 0.78), 1.4)
	_accent(parent, Vector3(0, 5, -30), Color(0.8, 0.9, 1.0), 2.0, 22.0)


## Slough of Despond — a vast murky mire, sinking debris, sickly underglow, and
## a far promise of solid ground.
static func _slough(parent: Node3D) -> void:
	var rng := _rng(102)
	for s in [-1.0, 1.0]:
		_water(parent, Vector3(s * 10.0, 0.15, -16), Vector2(11, 40), Color(0.36, 0.34, 0.28), Color(0.1, 0.12, 0.09), 0.86)
		_accent(parent, Vector3(s * 9.0, 0.6, -16), Color(0.4, 0.5, 0.38), 1.4, 16.0)
	for i in range(8):
		var x := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(8, 13)
		_dead_tree(parent, Vector3(x, 0, rng.randf_range(-32, 2)), rng.randf_range(2.6, 4.2), rng)
	# Broken cart / posts half-sunk near the deepest mire.
	for i in range(5):
		var post := _mi(_box(Vector3(0.3, rng.randf_range(1.2, 2.2), 0.3)), MaterialKit.make("wood", Color(0.3, 0.26, 0.2)), Vector3(rng.randf_range(-7, 7), 0.4, rng.randf_range(-34, -20)))
		post.rotation_degrees = Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
		parent.add_child(post)
	PropKit.reeds(parent, Vector3(-8, 0, -6), Vector2(7, 14), 30, Color(0.4, 0.45, 0.34))
	PropKit.reeds(parent, Vector3(8, 0, -40), Vector2(7, 12), 26, Color(0.38, 0.43, 0.32))
	# Solid ground waiting beyond (exit at -50).
	_glow_disc(parent, Vector3(0, 4, -50), 5.0, Color(0.9, 0.88, 0.7), 1.0)
	_accent(parent, Vector3(0, 3, -48), Color(1.0, 0.9, 0.65), 2.2, 18.0)


## Wicket Gate — the gate set in a great walled rampart with corner towers, ivy,
## and welcoming beams streaming out toward the pilgrim. (Corridor |x|<5.)
static func _wicket_gate(parent: Node3D) -> void:
	var stone := Color(0.32, 0.31, 0.35)
	PropKit.castle_wall(parent, Vector3(-14, 0, -27), 18, 7, stone, 0, 211)
	PropKit.castle_wall(parent, Vector3(14, 0, -27), 18, 7, stone, 0, 212)
	for s in [-1.0, 1.0]:
		_tower(parent, s * 12.0, -28, 4.0, 10.0, MaterialKit.make("stone", stone), false)
		# ivy
		parent.add_child(_mi(_box(Vector3(0.3, 5, 2.5)), MaterialKit.make("foliage", Color(0.3, 0.45, 0.28)), Vector3(s * 5.6, 3, -27)))
	_ray(parent, Vector3(0, 4, -19), 10, 2.6, Color(1.0, 0.92, 0.7), 1.0, -28, 0)
	_ray(parent, Vector3(-1.5, 4, -20), 9, 1.6, Color(1.0, 0.9, 0.66), 0.7, -24, 6)
	_ray(parent, Vector3(1.5, 4, -20), 9, 1.6, Color(1.0, 0.9, 0.66), 0.7, -24, -6)
	_glow_disc(parent, Vector3(0, 3, -23), 4.0, Color(1.0, 0.93, 0.72), 1.6)
	_spot(parent, Vector3(0, 5, -24), Vector3(0, 1.5, 0), Color(1.0, 0.9, 0.66), 6.0, 46.0, 40.0)
	_embers(parent, Vector3(0, 2.5, -16), Vector3(2, 2, 6), Color(1.0, 0.93, 0.72), 26, 0.2, "mote")
	PropKit.lantern_post(parent, Vector3(-4.5, 0, -19), stone, Color(1.0, 0.82, 0.5))
	PropKit.lantern_post(parent, Vector3(4.5, 0, -19), stone, Color(1.0, 0.82, 0.5))


## Interpreter's House — a candlelit interior: walls, beamed ceiling, a doorway,
## glowing emblem pictures, ranked candles, a hearth and warm dust.
static func _interpreter(parent: Node3D) -> void:
	var wood := MaterialKit.make("wood", Color(0.32, 0.24, 0.18))
	parent.add_child(_mi(_box(Vector3(0.6, 6, 34)), wood, Vector3(-11, 3, -7)))
	parent.add_child(_mi(_box(Vector3(0.6, 6, 34)), wood, Vector3(11, 3, -7)))
	parent.add_child(_mi(_box(Vector3(22, 0.5, 34)), wood, Vector3(0, 6, -7)))
	for z in [-2, -10, -18]:
		parent.add_child(_mi(_box(Vector3(22, 0.4, 0.6)), wood, Vector3(0, 5.6, z)))
	# Far wall with a lit doorway.
	parent.add_child(_mi(_box(Vector3(22, 6, 0.6)), wood, Vector3(0, 3, -23.5)))
	parent.add_child(_mi(_box(Vector3(2.4, 4, 0.7)), _emit(Color(1.0, 0.82, 0.5), 1.2), Vector3(0, 2, -23.2)))
	# Emblem pictures + a candle below each.
	for z in [-3.0, -9.0, -15.0]:
		for s in [-1.0, 1.0]:
			parent.add_child(_mi(_box(Vector3(0.3, 1.8, 1.4)), _emit(Color(1.0, 0.8, 0.45), 1.0), Vector3(s * 10.6, 3.0, z)))
			PropKit.lantern_post(parent, Vector3(s * 9.4, 0, z), Color(0.32, 0.24, 0.18), Color(1.0, 0.78, 0.42), 1.4)
	# Hearth.
	parent.add_child(_mi(_box(Vector3(3, 2.4, 0.6)), MaterialKit.make("stone", Color(0.4, 0.36, 0.32)), Vector3(0, 1.2, -22)))
	PropKit.fire(parent, Vector3(0, 0.6, -21.6), 0.9, Color(1.0, 0.6, 0.25))
	_embers(parent, Vector3(0, 2.5, -10), Vector3(8, 2.5, 14), Color(1.0, 0.85, 0.55), 28, 0.15, "mote")


## Hill Difficulty — a layered summit massif, a terraced climb, a clear spring,
## and two shadowed side-roads with dead trees.
static func _hill(parent: Node3D) -> void:
	PropKit.cliff(parent, Vector3(0, 0, -42), Vector3(16, 24, 14), Color(0.5, 0.49, 0.46), "stone", 201)
	PropKit.cliff(parent, Vector3(-13, 0, -34), Vector3(8, 16, 12), Color(0.48, 0.47, 0.44), "stone", 203)
	PropKit.cliff(parent, Vector3(13, 0, -36), Vector3(8, 18, 12), Color(0.5, 0.48, 0.45), "stone", 204)
	PropKit.ridge(parent, Vector3(0, 0, -58), 84, 32, Color(0.46, 0.5, 0.54), "stone", 202)
	# Terraced stepping stones climbing the flanks.
	var rng := _rng(205)
	for i in range(6):
		PropKit.rock(parent, Vector3(-10 + i * 0.6, 0, -10 - i * 3.5), rng.randf_range(1.0, 1.8), Color(0.5, 0.49, 0.46), "stone", rng.randi())
	# Clear spring at the foot.
	_water(parent, Vector3(-7, 0.1, 4), Vector2(5, 5), Color(0.55, 0.72, 0.78), Color(0.2, 0.4, 0.5), 0.8)
	_embers(parent, Vector3(-7, 0.4, 4), Vector3(2.2, 0.5, 2.2), Color(0.7, 0.85, 0.95), 18, 0.3, "mote")
	# Shadowed side-roads (decor portals + dead trees + cold glow).
	for s in [-1.0, 1.0]:
		var darkmat := _emit(Color(0.05, 0.05, 0.07), 0.0)
		parent.add_child(_mi(_box(Vector3(0.6, 4, 3)), darkmat, Vector3(s * 16.0, 2, -25)))
		parent.add_child(_mi(_box(Vector3(3, 0.6, 3)), darkmat, Vector3(s * 16.0 - s * 1.2, 4, -25)))
		_dead_tree(parent, Vector3(s * 13.0, 0, -22), 3.2, rng)
		_accent(parent, Vector3(s * 15.0, 1.5, -25), Color(0.3, 0.35, 0.5), 1.2, 10.0)
	# Bright summit.
	_ray(parent, Vector3(0, 14, -44), 16, 4, Color(1.0, 0.96, 0.82), 0.8)
	_glow_disc(parent, Vector3(0, 18, -46), 7.0, Color(1.0, 0.96, 0.82), 1.2)


## Palace Beautiful — the stately palace crowning the hill: a central keep,
## spired towers with lit windows, guardian lions, braziers and banners.
static func _palace(parent: Node3D) -> void:
	var pale := Color(0.8, 0.76, 0.7)
	var mat := MaterialKit.make("stone", pale)
	# Central keep + flanking towers behind the palace wall.
	_tower(parent, 0, -32, 5.0, 16.0, mat, true)
	for x in [-9.0, 9.0, -4.5, 4.5]:
		var h := 9.0 if absf(x) > 6.0 else 12.0
		_tower(parent, x, -30, 3.0, h, mat, true)
		parent.add_child(_mi(_box(Vector3(0.6, 1.4, 0.9)), _emit(Color(1.0, 0.82, 0.5), 1.5), Vector3(x, h * 0.6, -28.4)))
	# Guardian lions flanking the approach.
	_lion(parent, Vector3(-6.5, 0, -3), 90, pale)
	_lion(parent, Vector3(6.5, 0, -3), -90, pale)
	# Braziers lighting the way.
	for z in [-6.0, -14.0]:
		for s in [-1.0, 1.0]:
			parent.add_child(_mi(_cone(0.4, 0.25, 1.0, 8), mat, Vector3(s * 7.0, 0.5, z)))
			PropKit.fire(parent, Vector3(s * 7.0, 1.1, z), 0.7, Color(1.0, 0.7, 0.3))
	PropKit.banner(parent, Vector3(-5, 0, -23), 6, Color(0.7, 0.2, 0.25))
	PropKit.banner(parent, Vector3(5, 0, -23), 6, Color(0.25, 0.3, 0.7))
	_glow_disc(parent, Vector3(0, 12, -34), 8.0, Color(1.0, 0.85, 0.55), 1.0)
	_accent(parent, Vector3(0, 8, -28), Color(1.0, 0.85, 0.55), 3.0, 26.0)


## Valley of Humiliation — Apollyon's brimstone gorge: a fiery maw with burning
## eyes, lava cracks, scorched spires, fire jets and a hellish underglow.
static func _valley_humiliation(parent: Node3D) -> void:
	var dark := MaterialKit.make("ash", Color(0.16, 0.13, 0.13))
	var rng := _rng(701)
	# The maw archway.
	parent.add_child(_mi(_box(Vector3(3, 13, 3)), dark, Vector3(-5, 6.5, -34)))
	parent.add_child(_mi(_box(Vector3(3, 13, 3)), dark, Vector3(5, 6.5, -34)))
	parent.add_child(_mi(_box(Vector3(13, 3, 3)), dark, Vector3(0, 13, -34)))
	parent.add_child(_mi(_box(Vector3(9, 8, 0.6)), _emit(Color(1.0, 0.4, 0.12), 1.8, true), Vector3(0, 5.5, -33.5)))
	# Burning eyes.
	for s in [-1.0, 1.0]:
		parent.add_child(_mi(_dome(0.5), _emit(Color(1.0, 0.85, 0.2), 3.0), Vector3(s * 1.6, 9, -33.4)))
	# Scorched spires lining the gorge.
	for i in range(8):
		var s := -1.0 if i % 2 == 0 else 1.0
		parent.add_child(_mi(_cone(0.0, rng.randf_range(0.8, 1.6), rng.randf_range(4, 8), 6), dark, Vector3(s * rng.randf_range(9, 13), 0, rng.randf_range(-28, -8))))
	# Lava cracks on the ground (emissive strips).
	for i in range(5):
		parent.add_child(_mi(_box(Vector3(rng.randf_range(3, 8), 0.1, 0.3)), _emit(Color(1.0, 0.4, 0.1), 1.6, true), Vector3(rng.randf_range(-6, 6), 0.06, rng.randf_range(-26, -10))))
	PropKit.fire(parent, Vector3(-3, 0.4, -32), 1.6, Color(1.0, 0.45, 0.14))
	PropKit.fire(parent, Vector3(3, 0.4, -32), 1.6, Color(1.0, 0.5, 0.18))
	_embers(parent, Vector3(0, 7, -26), Vector3(16, 6, 12), Color(1.0, 0.5, 0.18), 64)
	_accent(parent, Vector3(0, 3, -32), Color(1.0, 0.35, 0.1), 4.0, 30.0)
	_accent(parent, Vector3(-7, 1.5, -18), Color(1.0, 0.4, 0.12), 2.0, 14.0)
	_accent(parent, Vector3(7, 1.5, -22), Color(1.0, 0.4, 0.12), 2.0, 14.0)


## Valley of the Shadow of Death — a tight overhanging chasm (corridor x±4),
## black voids either hand, cold ground-flames, will-o-wisps and a far dawn.
static func _valley_shadow(parent: Node3D) -> void:
	var blackrock := MaterialKit.make("stone", Color(0.1, 0.1, 0.13))
	var rng := _rng(801)
	for s in [-1.0, 1.0]:
		parent.add_child(_mi(_box(Vector3(2.6, 22, 90)), blackrock, Vector3(s * 6.0, 9, -20)))
		# overhang
		parent.add_child(_mi(_box(Vector3(3, 1.2, 90)), blackrock, Vector3(s * 5.0, 17, -20)))
		# the ditch / quag void
		parent.add_child(_mi(_box(Vector3(3, 0.4, 90)), _emit(Color(0.02, 0.02, 0.04), 0.0), Vector3(s * 5.2, -1.6, -20)))
		# jagged stalactites
		for i in range(6):
			parent.add_child(_mi(_cone(0.0, rng.randf_range(0.3, 0.7), rng.randf_range(2, 4), 5), blackrock, Vector3(s * rng.randf_range(4.5, 6.5), 15, rng.randf_range(2, -42))))
	# Cold ground-flames + will-o-wisps.
	for z in [-6.0, -18.0, -30.0]:
		PropKit.fire(parent, Vector3(-3.4, 0.1, z), 0.5, Color(0.5, 0.7, 1.0))
		PropKit.fire(parent, Vector3(3.4, 0.1, z + 6.0), 0.5, Color(0.5, 0.7, 1.0))
	_embers(parent, Vector3(0, 1.5, -20), Vector3(3.5, 1.5, 40), Color(0.4, 0.6, 1.0), 30, 0.05, "mote")
	# Faint cold dawn far beyond.
	_ray(parent, Vector3(0, 9, -52), 18, 3.2, Color(0.7, 0.82, 1.0), 0.9)
	_glow_disc(parent, Vector3(0, 6, -54), 5.0, Color(0.7, 0.82, 1.0), 1.2)


## Vanity Fair — a teeming worldly market: rows of gaudy stalls, festive bunting
## and lamps, a crowd, a stage and a gilded idol.
static func _vanity_fair(parent: Node3D) -> void:
	var rng := _rng(901)
	var cloths := [Color(0.8, 0.2, 0.25), Color(0.2, 0.4, 0.75), Color(0.8, 0.7, 0.2), Color(0.5, 0.2, 0.6), Color(0.2, 0.6, 0.4)]
	var zi := 0
	for z in [-4.0, -14.0, -24.0]:
		PropKit.market_stall(parent, Vector3(-9, 0, z), Color(1, 1, 1), cloths[zi % cloths.size()])
		PropKit.market_stall(parent, Vector3(9, 0, z + 4.0), Color(1, 1, 1), cloths[(zi + 2) % cloths.size()])
		PropKit.lantern_post(parent, Vector3(-6, 0, z), Color(1, 1, 1), Color(1.0, 0.8, 0.4))
		PropKit.lantern_post(parent, Vector3(6, 0, z + 4.0), Color(1, 1, 1), Color(1.0, 0.8, 0.4))
		zi += 1
	_bunting(parent, Vector3(-9, 4.6, -9), Vector3(9, 4.6, -9), 16)
	_bunting(parent, Vector3(-9, 4.3, -19), Vector3(9, 4.3, -19), 16)
	_bunting(parent, Vector3(-9, 4.4, -29), Vector3(9, 4.4, -29), 16)
	# A crowd lining the street.
	for i in range(10):
		var s := -1.0 if i % 2 == 0 else 1.0
		_figure(parent, Vector3(s * rng.randf_range(6.5, 8.5), 0, rng.randf_range(-2, -28)), Color.from_hsv(rng.randf(), 0.5, 0.7))
	# Gilded idol on a stage, set BEHIND the chapter's exit (z=-32) so the pilgrim
	# sees it ahead but advances before reaching it (no walk-through).
	parent.add_child(_mi(_box(Vector3(6, 0.6, 4)), MaterialKit.make("wood", Color(0.4, 0.3, 0.2)), Vector3(0, 0.3, -38)))
	parent.add_child(_mi(_box(Vector3(1.2, 4, 1.2)), MaterialKit.make("gold", Color(1.0, 0.85, 0.4), {"emission": 0.6}), Vector3(0, 2.6, -38)))
	parent.add_child(_mi(_dome(0.9), MaterialKit.make("gold", Color(1.0, 0.85, 0.4), {"emission": 0.6}), Vector3(0, 5.0, -38)))
	_accent(parent, Vector3(0, 4, -37), Color(1.0, 0.85, 0.4), 2.5, 18.0)


## Doubting Castle — the grim fortress looming over the cell: a towering keep,
## battlemented curtain walls, hanging cages, cold moonlight and creeping mist.
static func _doubting_castle(parent: Node3D) -> void:
	var grim := Color(0.26, 0.27, 0.32)
	var mat := MaterialKit.make("stone", grim)
	PropKit.castle_wall(parent, Vector3(-13, 0, -30), 34, 11, grim, 1, 301)
	PropKit.castle_wall(parent, Vector3(13, 0, -30), 34, 11, grim, 1, 302)
	PropKit.castle_wall(parent, Vector3(0, 0, -46), 30, 13, grim, 0, 303)
	# A great central keep + corner towers.
	_tower(parent, 0, -50, 8.0, 24.0, mat, false)
	for x in [-13.0, 13.0]:
		_tower(parent, x, -46, 6.0, 18.0, mat, false)
		parent.add_child(_mi(_box(Vector3(0.8, 1.6, 0.4)), _emit(Color(0.5, 0.6, 0.8), 0.8), Vector3(x, 12, -43)))
	# Hanging cages over the courtyard.
	for x in [-6.0, 6.0]:
		parent.add_child(_mi(_box(Vector3(0.1, 3, 0.1)), mat, Vector3(x, 8, -22)))
		parent.add_child(_mi(_box(Vector3(1.0, 1.4, 1.0)), mat, Vector3(x, 5.5, -22)))
	PropKit.mist(parent, Vector3(0, 0, -34), Vector2(34, 36), 2.2, Color(0.3, 0.32, 0.4))
	# Cold moonlight from above, a lone warm cell-torch for contrast near spawn.
	_spot(parent, Vector3(0, 30, -40), Vector3(0, 2, -20), Color(0.6, 0.68, 0.85), 6.0, 50.0, 70.0)
	_accent(parent, Vector3(-3, 2.5, -2), Color(1.0, 0.7, 0.4), 1.6, 8.0)


## Delectable Mountains — sunlit rolling hills, a shepherds' lookout, flocks,
## wildflowers, and a first far glimpse of the shining Celestial City.
static func _delectable(parent: Node3D) -> void:
	var rng := _rng(401)
	var grass := MaterialKit.make("grass", Color(0.36, 0.56, 0.3))
	for i in range(6):
		var r := rng.randf_range(7, 14)
		var mound := _mi(_dome(r), grass, Vector3(rng.randf_range(-16, 16), -r * 0.45, rng.randf_range(-28, -46)))
		mound.scale = Vector3(1.5, 0.7, 1.5)
		parent.add_child(mound)
	# Shepherds' lookout: a railed wooden platform with a perspective glass.
	var wood := MaterialKit.make("wood", Color(0.45, 0.34, 0.22))
	parent.add_child(_mi(_box(Vector3(3, 0.3, 3)), wood, Vector3(-10, 1.0, -8)))
	for cx in [-11.2, -8.8]:
		for cz in [-9.2, -6.8]:
			parent.add_child(_mi(_box(Vector3(0.2, 1.0, 0.2)), wood, Vector3(cx, 0.5, cz)))
	parent.add_child(_mi(_cone(0.05, 0.12, 1.2, 6), MaterialKit.make("gold", Color(0.9, 0.8, 0.5)), Vector3(-10, 1.8, -8)))
	# Wildflowers (scattered colour dots) + a couple more sheep.
	for i in range(24):
		parent.add_child(_mi(_box(Vector3(0.18, 0.4, 0.18)), MaterialKit.make("cloth", Color.from_hsv(rng.randf(), 0.7, 0.95), {"tint_blend": 0.8}), Vector3(rng.randf_range(-16, 16), 0.2, rng.randf_range(-22, 4))))
	for i in range(4):
		PropKit.sheep(parent, Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-18, -2)), rng.randi())
	# The distant shining City.
	for x in [-1.5, 0.0, 1.5]:
		parent.add_child(_mi(_box(Vector3(1, 4, 1)), _emit(Color(1.0, 0.88, 0.55), 2.0, true), Vector3(x, 2.5, -54)))
	_glow_disc(parent, Vector3(0, 4, -54), 5.0, Color(1.0, 0.92, 0.66), 1.4)
	_ray(parent, Vector3(0, 8, -54), 12, 2.0, Color(1.0, 0.95, 0.78), 0.7)


## Enchanted Ground — drowsy glowing arbours that lure to sleep: full leafy
## bowers with cushions, luring will-o-lights, giant dream-flowers and spores.
static func _enchanted(parent: Node3D) -> void:
	for z in [-12.0, -28.0]:
		for s in [-1.0, 1.0]:
			var x: float = s * 8.0
			PropKit.arch(parent, Vector3(x, 0, z), 3.2, 3.4, Color(0.5, 0.46, 0.4), "wood")
			parent.add_child(_mi(_dome(2.4), MaterialKit.make("foliage", Color(0.4, 0.5, 0.38)), Vector3(x, 3.6, z)))
			parent.add_child(_mi(_box(Vector3(2.4, 0.5, 1.0)), MaterialKit.make("cloth", Color(0.6, 0.5, 0.62)), Vector3(x, 0.5, z)))
			_accent(parent, Vector3(x, 2.2, z), Color(0.7, 0.62, 0.85), 1.8, 7.0)
			_glow_disc(parent, Vector3(x, 2.4, z), 2.4, Color(0.75, 0.65, 0.9), 0.8)
	# Giant glowing dream-flowers on stalks.
	var rng := _rng(1101)
	for i in range(7):
		var x := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(4, 11)
		var fz := rng.randf_range(-38, -4)
		var hh := rng.randf_range(1.2, 2.2)
		parent.add_child(_mi(_cone(0.04, 0.08, hh, 5), MaterialKit.make("foliage", Color(0.36, 0.46, 0.34)), Vector3(x, hh * 0.5, fz)))
		parent.add_child(_mi(_dome(0.5), _emit(Color.from_hsv(rng.randf_range(0.6, 0.85), 0.5, 0.9), 1.4), Vector3(x, hh + 0.3, fz)))
	_embers(parent, Vector3(0, 3, -22), Vector3(13, 4, 34), Color(0.8, 0.72, 0.9), 44, 0.1, "mote")


## Wilderness Road — vast austere emptiness: layered mesas, an arch rock, dead
## trees, scattered boulders and bleached bones, a lonely far goal. (Ground x±6.)
static func _wilderness(parent: Node3D) -> void:
	var rng := _rng(501)
	var stone := MaterialKit.make("dry_earth", Color(0.55, 0.48, 0.38))
	for i in range(6):
		var w := rng.randf_range(8, 16)
		var h := rng.randf_range(8, 18)
		parent.add_child(_mi(_box(Vector3(w, h, w * 0.8)), stone, Vector3(rng.randf_range(-24, 24), h * 0.5, rng.randf_range(-44, -64))))
	# An arch rock formation.
	parent.add_child(_mi(_box(Vector3(3, 8, 3)), stone, Vector3(-16, 4, -30)))
	parent.add_child(_mi(_box(Vector3(3, 8, 3)), stone, Vector3(-10, 4, -30)))
	parent.add_child(_mi(_box(Vector3(9, 2.5, 3)), stone, Vector3(-13, 8.5, -30)))
	for i in range(8):
		var x := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(8, 17)
		PropKit.rock(parent, Vector3(x, 0, rng.randf_range(-38, 4)), rng.randf_range(0.8, 2.2), Color(0.56, 0.5, 0.42), "dry_earth", rng.randi())
	for i in range(3):
		_dead_tree(parent, Vector3((-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(8, 14), 0, rng.randf_range(-34, -6)), rng.randf_range(2.5, 3.6), rng)
	# Bleached bones beside the road.
	for i in range(4):
		var bx := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(7, 10)
		var bz := rng.randf_range(-30, 0)
		parent.add_child(_mi(_dome(0.4), MaterialKit.make("cloth", Color(0.85, 0.82, 0.72)), Vector3(bx, 0.3, bz)))
		for k in range(4):
			parent.add_child(_mi(_cone(0.04, 0.06, 0.9, 4), MaterialKit.make("cloth", Color(0.82, 0.8, 0.7)), Vector3(bx + rng.randf_range(-0.6, 0.6), 0.2, bz + 0.6 + k * 0.2)))
	_ray(parent, Vector3(0, 7, -58), 14, 2.2, Color(1.0, 0.96, 0.82), 0.6)
	_glow_disc(parent, Vector3(0, 6, -60), 5.0, Color(1.0, 0.95, 0.8), 1.0)


## River of Death — the far shore in radiant glory: a shining gate-city, hosts
## of light, beams, an animated shimmer over the crossing.
static func _river(parent: Node3D) -> void:
	_water(parent, Vector3(0, 0.12, -7), Vector2(30, 26), Color(0.5, 0.62, 0.72), Color(0.12, 0.2, 0.3), 0.55)
	# A shining gate-city on the far shore.
	var goldmat := MaterialKit.make("gold", Color(1.0, 0.85, 0.45), {"emission": 0.6})
	parent.add_child(_mi(_box(Vector3(4, 6, 2)), goldmat, Vector3(0, 3, -34)))
	parent.add_child(_mi(_dome(2.0), goldmat, Vector3(0, 6.5, -34)))
	for x in [-6.0, 6.0]:
		_tower(parent, x, -34, 2.0, 7.0, goldmat, true)
	# Hosts of light waiting.
	for x in [-7.0, -3.0, 3.0, 7.0]:
		parent.add_child(_mi(_cone(0.0, 0.6, 3.4, 8), _emit(Color(1.0, 0.96, 0.8), 2.2, true), Vector3(x, 1.7, -30)))
	_ray(parent, Vector3(0, 12, -34), 22, 5, Color(1.0, 0.96, 0.82), 1.0)
	_ray(parent, Vector3(-6, 11, -33), 18, 3, Color(1.0, 0.94, 0.78), 0.8, 0, 8)
	_ray(parent, Vector3(6, 11, -33), 18, 3, Color(1.0, 0.94, 0.78), 0.8, 0, -8)
	_glow_disc(parent, Vector3(0, 7, -36), 9.0, Color(1.0, 0.95, 0.78), 1.6)
	_spot(parent, Vector3(0, 16, -40), Vector3(0, 2, -20), Color(1.0, 0.96, 0.8), 8.0, 46.0, 60.0)


## The Cross and the Tomb — dawn breaking in glory over the Cross: a radiant
## sunrise, fanned beams, a halo over the hill, distant hills and rising motes.
static func _cross_dawn(parent: Node3D) -> void:
	_glow_disc(parent, Vector3(0, 9, -30), 12.0, Color(1.0, 0.9, 0.7), 1.6)
	_ray(parent, Vector3(0, 12, -24), 22, 5, Color(1.0, 0.92, 0.74), 1.1)
	_ray(parent, Vector3(-5, 11, -23), 18, 3, Color(1.0, 0.9, 0.7), 0.8, 0, 7)
	_ray(parent, Vector3(5, 11, -23), 18, 3, Color(1.0, 0.9, 0.7), 0.8, 0, -7)
	_ray(parent, Vector3(-9, 10, -22), 15, 2.4, Color(1.0, 0.9, 0.7), 0.6, 0, 12)
	_ray(parent, Vector3(9, 10, -22), 15, 2.4, Color(1.0, 0.9, 0.7), 0.6, 0, -12)
	PropKit.ridge(parent, Vector3(0, 0, -42), 74, 15, Color(0.45, 0.55, 0.4), "grass", 601)
	# A warm halo + backlight on the Cross (chapter builds the Cross at z=-18).
	_glow_disc(parent, Vector3(0, 6, -19), 5.0, Color(1.0, 0.95, 0.78), 1.2)
	_spot(parent, Vector3(0, 14, -30), Vector3(0, 5, -18), Color(1.0, 0.92, 0.74), 6.0, 44.0, 50.0)
	_embers(parent, Vector3(0, 4, -18), Vector3(16, 5, 10), Color(1.0, 0.92, 0.7), 50, 0.5, "mote")

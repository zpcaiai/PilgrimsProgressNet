extends RefCounted
class_name CelestialCityArt
## Bespoke "showcase" art for the Celestial City — the journey's climax, pushed
## as far as the engine allows. Builds a tiered radiant gold city rising on a
## hill BEHIND the gate, a blazing gate-of-light curtain, layered animated
## god-ray shafts, a glory backlight and rising golden motes.
##
## Everything sits at z <= -32 (the gate is at z=-30, the arrival trigger at
## z=-27), so the whole spectacle frames the destination the pilgrim walks
## toward without ever blocking the corridor or the trigger.
##
## Uses the animated glory_gold / godray shaders when present, and falls back to
## emissive StandardMaterial3D so it still glows if the shaders are missing.

const GOLD_SHADER := "res://assets/shaders/glory_gold.gdshader"
const RAY_SHADER := "res://assets/shaders/godray.gdshader"
const GOLD := Color(1.0, 0.82, 0.42)


static func build(parent: Node3D) -> void:
	var gold := _gold_mat()
	_hill(parent, gold)
	_city(parent, gold)
	_front_wall(parent, gold)
	_banners(parent)
	_glory_lights(parent)
	# Stylised glory effects (god-rays, gate-of-light curtain, rising motes) are
	# skipped in realistic mode — a real sunlit stone city on a hill instead.
	if not RenderConfig.is_realistic():
		_god_rays(parent)
		_gate_curtain(parent)
		_motes(parent)


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------
static func _gold_mat() -> Material:
	# Realistic mode: a real sunlit pale-stone city, not glowing gold.
	if RenderConfig.is_realistic():
		return MaterialKit.make("marble", Color(0.82, 0.78, 0.7))
	var sh := load(GOLD_SHADER)
	if sh is Shader:
		var m := ShaderMaterial.new()
		m.shader = sh
		return m
	var sm := StandardMaterial3D.new()
	sm.albedo_color = GOLD
	sm.metallic = 0.7
	sm.roughness = 0.32
	sm.emission_enabled = true
	sm.emission = GOLD
	sm.emission_energy_multiplier = 0.8
	return sm


static func _ray_mat(color: Color, intensity: float, height: float) -> Material:
	var sh := load(RAY_SHADER)
	if sh is Shader:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("ray_color", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("intensity", intensity)
		m.set_shader_parameter("beam_height", height)
		return m
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(color.r, color.g, color.b, 0.12)
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = intensity
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	return sm


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
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
	s.height = r * 1.4
	s.radial_segments = 12
	s.rings = 7
	return s


# ---------------------------------------------------------------------------
# Set pieces
# ---------------------------------------------------------------------------
## The luminous hill the City crowns.
static func _hill(parent: Node3D, mat: Material) -> void:
	var hill := _mi(_cone(20.0, 26.0, 6.0, 24), mat, Vector3(0, -1.0, -47))
	parent.add_child(hill)


## A single gold tower: shaft + domed/spired cap.
static func _tower(parent: Node3D, mat: Material, x: float, z: float, w: float, h: float, spire: bool) -> void:
	parent.add_child(_mi(_box(Vector3(w, h, w)), mat, Vector3(x, h * 0.5, z)))
	if spire:
		parent.add_child(_mi(_cone(0.0, w * 0.7, w * 1.8, 8), mat, Vector3(x, h + w * 0.9, z)))
	else:
		parent.add_child(_mi(_dome(w * 0.62), mat, Vector3(x, h + w * 0.2, z)))


## Tiered skyline: rows climb in height toward the back and toward the centre,
## so the City reads as a great pyramid of light on the hill.
static func _city(parent: Node3D, mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260616
	# row: z, count, half_spread, base_h, spire
	var rows := [
		[-37.0, 6, 18.0, 6.0, false],
		[-43.0, 5, 15.0, 9.0, false],
		[-50.0, 4, 11.0, 13.0, true],
		[-56.0, 3, 6.0, 18.0, true],
	]
	for r in rows:
		var z: float = r[0]
		var count: int = r[1]
		var spread: float = r[2]
		var base_h: float = r[3]
		var spire: bool = r[4]
		for i in range(count):
			var fx := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * 2.0
			var x := fx * spread
			# taller toward the centre, plus a little variation
			var center_boost := 1.0 - 0.45 * absf(fx)
			var h := base_h * center_boost * rng.randf_range(0.85, 1.15)
			var w := rng.randf_range(2.0, 3.2)
			_tower(parent, mat, x, z, w, h, spire and absf(fx) < 0.7)


## A low castellated curtain wall fronting the City.
static func _front_wall(parent: Node3D, mat: Material) -> void:
	parent.add_child(_mi(_box(Vector3(40, 4.0, 1.2)), mat, Vector3(0, 2.0, -34)))
	for i in range(13):
		var x := -18.0 + i * 3.0
		parent.add_child(_mi(_box(Vector3(1.2, 1.2, 1.4)), mat, Vector3(x, 4.4, -34)))


static func _banners(parent: Node3D) -> void:
	PropKit.banner(parent, Vector3(-9, 0, -35), 6.0, Color(1.0, 0.88, 0.5))
	PropKit.banner(parent, Vector3(9, 0, -35), 6.0, Color(1.0, 0.95, 0.8))
	PropKit.banner(parent, Vector3(-15, 0, -36), 5.0, Color(0.95, 0.8, 0.45))
	PropKit.banner(parent, Vector3(15, 0, -36), 5.0, Color(0.95, 0.8, 0.45))


## Layered shafts of light streaming down over the City.
static func _god_rays(parent: Node3D) -> void:
	# x, z, top_y, height, top_radius, intensity, tilt_deg
	var beams := [
		[0.0, -48.0, 30.0, 28.0, 4.5, 0.9, 4.0],
		[-9.0, -44.0, 26.0, 24.0, 3.2, 0.75, 10.0],
		[9.0, -46.0, 27.0, 25.0, 3.4, 0.8, -9.0],
		[-14.0, -40.0, 22.0, 20.0, 2.6, 0.6, 14.0],
		[14.0, -42.0, 23.0, 21.0, 2.8, 0.65, -13.0],
		[0.0, -56.0, 33.0, 26.0, 3.0, 0.7, 3.0],
	]
	for b in beams:
		var x: float = b[0]
		var z: float = b[1]
		var top_y: float = b[2]
		var height: float = b[3]
		var top_r: float = b[4]
		var inten: float = b[5]
		var tilt: float = b[6]
		var mat := _ray_mat(Color(1.0, 0.95, 0.74), inten, height)
		var beam := _mi(_cone(top_r, 0.3, height, 14), mat, Vector3(x, top_y - height * 0.5, z))
		beam.rotation_degrees = Vector3(tilt, 0, tilt * 0.4)
		parent.add_child(beam)


## A blazing curtain of light filling the gate opening, facing the pilgrim.
static func _gate_curtain(parent: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(7.6, 9.0)
	var mat := _ray_mat(Color(1.0, 0.97, 0.82), 1.3, 9.0)
	parent.add_child(_mi(quad, mat, Vector3(0, 4.6, -29.85)))


## The light "from beyond" — a strong warm spot from behind the City toward the
## gate, plus soft omni fill inside the City.
static func _glory_lights(parent: Node3D) -> void:
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 34, -62)
	spot.light_color = Color(1.0, 0.95, 0.78)
	spot.light_energy = 12.0
	spot.spot_range = 80.0
	spot.spot_angle = 42.0
	spot.light_specular = 0.4
	parent.add_child(spot)
	spot.look_at(Vector3(0, 5, -30), Vector3.UP)

	for p in [Vector3(-8, 8, -48), Vector3(8, 8, -50), Vector3(0, 12, -55)]:
		var omni := OmniLight3D.new()
		omni.position = p
		omni.light_color = Color(1.0, 0.9, 0.62)
		omni.light_energy = 4.0
		omni.omni_range = 26.0
		parent.add_child(omni)


## Slowly rising golden motes — glory dust over the whole City.
static func _motes(parent: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.position = Vector3(0, 2, -47)
	p.amount = 70
	p.lifetime = 6.0
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 12, 12)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, 0.3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 1.1
	mat.color = Color(1.0, 0.92, 0.66)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.92, 0.66)
	dmat.emission_enabled = true
	dmat.emission = Color(1.0, 0.92, 0.66)
	dmat.emission_energy_multiplier = 2.4
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spr := AssetLib.particle("mote")
	if spr != null:
		dmat.albedo_texture = spr
		dmat.emission_texture = spr
	quad.material = dmat
	p.draw_pass_1 = quad
	parent.add_child(p)

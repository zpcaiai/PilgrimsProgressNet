extends RefCounted
class_name ChapterArt
## Bespoke "showcase" art for every chapter — the deep-polish layer.
##
## ChapterBase._apply_world_rebuild() calls build(self, id) AFTER the generic
## profile (lighting/fog/dressing) is applied, so each chapter gets a signature
## centrepiece on top of the shared system. Each builder adds the scene's iconic
## spectacle WITHOUT duplicating the gameplay geometry the chapter already
## builds, and keeps colliding pieces off the walkable corridor (positions are
## chosen from each chapter's known ground width / spawn / exit).
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
# Helpers
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


## An additive light shaft (animated godray shader, or emissive fallback).
static func _ray(parent: Node3D, pos: Vector3, height: float, top_r: float, color: Color, intensity: float, tilt_x: float = 0.0, tilt_z: float = 0.0) -> void:
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


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


# ===========================================================================
# Per-chapter centrepieces
# ===========================================================================

## City of Destruction — the doomed city ablaze BEHIND the fleeing pilgrim
## (spawn +8, flees toward -Z), with a far hope-gate glow ahead.
static func _city_of_destruction(parent: Node3D) -> void:
	var rng := _rng(101)
	var ash := MaterialKit.make("ash", Color(0.2, 0.17, 0.16))
	for i in range(7):
		var x := rng.randf_range(-17, 17)
		var z := rng.randf_range(16, 30)
		var h := rng.randf_range(6, 16)
		var w := rng.randf_range(2.5, 4.5)
		var t := _mi(_box(Vector3(w, h, w)), ash, Vector3(x, h * 0.5, z))
		t.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf_range(0, 30), rng.randf_range(-4, 4))
		parent.add_child(t)
		# fire glowing through the windows
		parent.add_child(_mi(_box(Vector3(w * 0.5, h * 0.5, w * 0.5)), _emit(Color(1.0, 0.45, 0.15), 2.2), Vector3(x, h * 0.4, z)))
		if rng.randf() < 0.7:
			PropKit.fire(parent, Vector3(x, h, z), rng.randf_range(0.8, 1.6), Color(1.0, 0.5, 0.18))
		PropKit.smoke(parent, Vector3(x, h + 1, z), rng.randf_range(1.6, 2.8), Color(0.1, 0.09, 0.09))
	# Ember rain over the ruins.
	_embers(parent, Vector3(0, 8, 22), Vector3(20, 8, 10), Color(1.0, 0.55, 0.2))
	# The far gate of escape, a cool bright promise ahead.
	_ray(parent, Vector3(0, 11, -32), 18, 4, Color(1.0, 0.95, 0.78), 0.9)


## Slough of Despond — a vast murky mire flanking the sunken road.
static func _slough(parent: Node3D) -> void:
	var rng := _rng(102)
	for s in [-1.0, 1.0]:
		_water(parent, Vector3(s * 10.0, 0.15, -14), Vector2(10, 30), Color(0.36, 0.34, 0.28), Color(0.12, 0.13, 0.1), 0.85)
	# Dead, half-sunk trees and broken posts.
	for i in range(6):
		var x := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(9, 13)
		var z := rng.randf_range(-30, 2)
		var trunk := _mi(_cone(0.12, 0.3, rng.randf_range(2.5, 4.0), 6), MaterialKit.make("bark", Color(0.2, 0.18, 0.15)), Vector3(x, 1.3, z))
		trunk.rotation_degrees = Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 360), rng.randf_range(-18, 18))
		parent.add_child(trunk)


## Wicket Gate — set the chapter's gate into a great wall, and pour welcoming
## light through it. (Chapter builds the gate + side walls within |x|<6.)
static func _wicket_gate(parent: Node3D) -> void:
	var stone := Color(0.3, 0.3, 0.34)
	# Long wall to either side of the gate (well outside the |x|<6 corridor).
	PropKit.wall(parent, Vector3(-14, 0, -27), 18, 7, stone, "stone", 0)
	PropKit.wall(parent, Vector3(14, 0, -27), 18, 7, stone, "stone", 0)
	# Welcoming beams streaming out through the gate toward the pilgrim.
	_ray(parent, Vector3(0, 4, -19), 10, 2.6, Color(1.0, 0.92, 0.7), 1.0, -28, 0)
	_ray(parent, Vector3(-1.5, 4, -20), 9, 1.6, Color(1.0, 0.9, 0.66), 0.7, -24, 6)
	_ray(parent, Vector3(1.5, 4, -20), 9, 1.6, Color(1.0, 0.9, 0.66), 0.7, -24, -6)
	PropKit.lantern_post(parent, Vector3(-4.5, 0, -19), stone, Color(1.0, 0.82, 0.5))
	PropKit.lantern_post(parent, Vector3(4.5, 0, -19), stone, Color(1.0, 0.82, 0.5))


## Interpreter's House — make it read as a candlelit interior: side walls, a
## beamed ceiling, framed emblem pictures and a hearth glow. (Ground x±12.)
static func _interpreter(parent: Node3D) -> void:
	var wood := MaterialKit.make("wood", Color(0.32, 0.24, 0.18))
	# Side walls + ceiling (corridor centre stays open; door gap at far end).
	parent.add_child(_mi(_box(Vector3(0.6, 6, 34)), wood, Vector3(-11, 3, -7)))
	parent.add_child(_mi(_box(Vector3(0.6, 6, 34)), wood, Vector3(11, 3, -7)))
	parent.add_child(_mi(_box(Vector3(22, 0.5, 34)), wood, Vector3(0, 6, -7)))
	for z in [-2, -10, -18]:
		parent.add_child(_mi(_box(Vector3(22, 0.4, 0.6)), wood, Vector3(0, 5.6, z)))
	# Framed emblem "pictures" glowing on the walls.
	for z in [-3.0, -9.0, -15.0]:
		parent.add_child(_mi(_box(Vector3(0.3, 1.8, 1.4)), _emit(Color(1.0, 0.8, 0.45), 1.0), Vector3(-10.6, 3.0, z)))
		parent.add_child(_mi(_box(Vector3(0.3, 1.8, 1.4)), _emit(Color(1.0, 0.82, 0.5), 1.0), Vector3(10.6, 3.0, z)))
	# Hearth at the far wall.
	parent.add_child(_mi(_box(Vector3(3, 2.4, 0.6)), MaterialKit.make("stone", Color(0.4, 0.36, 0.32)), Vector3(0, 1.2, -22)))
	PropKit.fire(parent, Vector3(0, 0.6, -21.6), 0.9, Color(1.0, 0.6, 0.25))


## Hill Difficulty — the steep summit massif beyond the climb, a spring at the
## foot, and two shadowed side-roads marked as dark portals.
static func _hill(parent: Node3D) -> void:
	PropKit.cliff(parent, Vector3(0, 0, -42), Vector3(16, 24, 14), Color(0.5, 0.49, 0.46), "stone", 201)
	PropKit.ridge(parent, Vector3(0, 0, -56), 80, 30, Color(0.46, 0.5, 0.54), "stone", 202)
	# Clear spring at the foot of the hill (off to one side near the start).
	_water(parent, Vector3(-7, 0.1, 4), Vector2(5, 5), Color(0.55, 0.72, 0.78), Color(0.2, 0.4, 0.5), 0.8)
	# Two easier side-roads veering into shadow (decor portals, non-colliding).
	for s in [-1.0, 1.0]:
		var dark := _emit(Color(0.05, 0.05, 0.07), 0.0, false, 1.0)
		parent.add_child(_mi(_box(Vector3(0.6, 4, 3)), dark, Vector3(s * 16.0, 2, -25)))
		parent.add_child(_mi(_box(Vector3(3, 0.6, 3)), dark, Vector3(s * 16.0 - s * 1.2, 4, -25)))


## Palace Beautiful — the stately palace crowning the hill, two guardian lions
## flanking the approach, banners and warm towers. (Chapter builds the walls.)
static func _palace(parent: Node3D) -> void:
	var pale := Color(0.78, 0.74, 0.68)
	# Towers rising behind the palace's back wall.
	for x in [-9.0, 9.0, -4.0, 4.0]:
		var h := 9.0 if absf(x) > 6.0 else 12.0
		parent.add_child(_mi(_box(Vector3(3, h, 3)), MaterialKit.make("stone", pale), Vector3(x, h * 0.5, -30)))
		parent.add_child(_mi(_cone(0.0, 2.0, 3.5, 8), MaterialKit.make("stone", pale), Vector3(x, h + 1.6, -30)))
		parent.add_child(_mi(_box(Vector3(0.6, 1.4, 0.9)), _emit(Color(1.0, 0.82, 0.5), 1.4), Vector3(x, h * 0.6, -28.4)))
	# Two chained lions flanking the path (decor).
	_lion(parent, Vector3(-6.5, 0, -3), 90, pale)
	_lion(parent, Vector3(6.5, 0, -3), -90, pale)
	PropKit.banner(parent, Vector3(-5, 0, -23), 6, Color(0.7, 0.2, 0.25))
	PropKit.banner(parent, Vector3(5, 0, -23), 6, Color(0.25, 0.3, 0.7))


## Valley of Humiliation — the brimstone valley with Apollyon's fiery maw ahead.
static func _valley_humiliation(parent: Node3D) -> void:
	# A great dark archway breathing fire (decor; the fight happens in front).
	var dark := MaterialKit.make("ash", Color(0.16, 0.13, 0.13))
	parent.add_child(_mi(_box(Vector3(3, 12, 3)), dark, Vector3(-5, 6, -34)))
	parent.add_child(_mi(_box(Vector3(3, 12, 3)), dark, Vector3(5, 6, -34)))
	parent.add_child(_mi(_box(Vector3(13, 3, 3)), dark, Vector3(0, 12.5, -34)))
	parent.add_child(_mi(_box(Vector3(9, 7, 0.6)), _emit(Color(1.0, 0.4, 0.12), 1.6, true), Vector3(0, 5, -33.5)))
	PropKit.fire(parent, Vector3(-3, 0.5, -32), 1.6, Color(1.0, 0.45, 0.14))
	PropKit.fire(parent, Vector3(3, 0.5, -32), 1.6, Color(1.0, 0.5, 0.18))
	_embers(parent, Vector3(0, 7, -28), Vector3(16, 6, 8), Color(1.0, 0.5, 0.18))


## Valley of the Shadow of Death — a tight chasm hugging the narrow ledge (x±4),
## black voids on either hand, and a faint cold dawn far ahead.
static func _valley_shadow(parent: Node3D) -> void:
	var blackrock := MaterialKit.make("stone", Color(0.1, 0.1, 0.13))
	for s in [-1.0, 1.0]:
		parent.add_child(_mi(_box(Vector3(2.5, 20, 90)), blackrock, Vector3(s * 6.0, 8, -20)))
		# the ditch / quag — a dark void plane just past the ledge
		parent.add_child(_mi(_box(Vector3(3, 0.4, 90)), _emit(Color(0.02, 0.02, 0.04), 0.0), Vector3(s * 5.2, -1.6, -20)))
	# A few cold ground-flames lining the path.
	for z in [-6.0, -18.0, -30.0]:
		PropKit.fire(parent, Vector3(-3.4, 0.1, z), 0.5, Color(0.5, 0.7, 1.0))
		PropKit.fire(parent, Vector3(3.4, 0.1, z + 6.0), 0.5, Color(0.5, 0.7, 1.0))
	# The faint cold dawn far beyond the valley's end.
	_ray(parent, Vector3(0, 9, -50), 18, 3.2, Color(0.7, 0.82, 1.0), 0.8)


## Vanity Fair — a bustling worldly market street: rows of gaudy stalls, festive
## bunting overhead and a gilded idol at the far end.
static func _vanity_fair(parent: Node3D) -> void:
	var cloths := [Color(0.8, 0.2, 0.25), Color(0.2, 0.4, 0.75), Color(0.8, 0.7, 0.2), Color(0.5, 0.2, 0.6), Color(0.2, 0.6, 0.4)]
	var zi := 0
	for z in [-4.0, -14.0, -24.0]:
		PropKit.market_stall(parent, Vector3(-9, 0, z), Color(1, 1, 1), cloths[zi % cloths.size()])
		PropKit.market_stall(parent, Vector3(9, 0, z + 4.0), Color(1, 1, 1), cloths[(zi + 2) % cloths.size()])
		zi += 1
	# Festive bunting (rows of little colour flags between poles).
	_bunting(parent, Vector3(-8, 4.5, -10), Vector3(8, 4.5, -10), 14)
	_bunting(parent, Vector3(-8, 4.2, -20), Vector3(8, 4.2, -20), 14)
	# A gilded idol at the far end (decor).
	parent.add_child(_mi(_box(Vector3(1.2, 4, 1.2)), MaterialKit.make("gold", Color(1.0, 0.85, 0.4), {"emission": 0.5}), Vector3(0, 2, -30)))
	parent.add_child(_mi(_dome(0.9), MaterialKit.make("gold", Color(1.0, 0.85, 0.4), {"emission": 0.5}), Vector3(0, 4.4, -30)))


## Doubting Castle — the grim fortress looming around the cell.
static func _doubting_castle(parent: Node3D) -> void:
	var grim := Color(0.26, 0.27, 0.32)
	PropKit.castle_wall(parent, Vector3(-13, 0, -30), 34, 11, grim, 1, 301)
	PropKit.castle_wall(parent, Vector3(13, 0, -30), 34, 11, grim, 1, 302)
	PropKit.castle_wall(parent, Vector3(0, 0, -46), 30, 13, grim, 0, 303)
	# Two great towers.
	for x in [-13.0, 13.0]:
		parent.add_child(_mi(_box(Vector3(6, 18, 6)), MaterialKit.make("stone", grim), Vector3(x, 9, -46)))
		parent.add_child(_mi(_box(Vector3(7, 1.4, 7)), MaterialKit.make("stone", grim), Vector3(x, 18.5, -46)))
		# a single cold barred window
		parent.add_child(_mi(_box(Vector3(0.8, 1.6, 0.4)), _emit(Color(0.5, 0.6, 0.8), 0.8), Vector3(x, 12, -43)))
	PropKit.mist(parent, Vector3(0, 0, -34), Vector2(34, 36), 2.0, Color(0.3, 0.32, 0.4))


## Delectable Mountains — rolling green hills, and a first far glimpse of the
## shining Celestial City on the horizon.
static func _delectable(parent: Node3D) -> void:
	var rng := _rng(401)
	var grass := MaterialKit.make("grass", Color(0.36, 0.56, 0.3))
	for i in range(5):
		var x := rng.randf_range(-16, 16)
		var z := rng.randf_range(-30, -44)
		var r := rng.randf_range(7, 13)
		var mound := _mi(_dome(r), grass, Vector3(x, -r * 0.45, z))
		mound.scale = Vector3(1.5, 0.7, 1.5)
		parent.add_child(mound)
	# The distant shining City — small, bright, far away.
	for x in [-1.5, 0.0, 1.5]:
		parent.add_child(_mi(_box(Vector3(1, 4, 1)), _emit(Color(1.0, 0.88, 0.55), 2.0, true), Vector3(x, 2.5, -54)))
	_ray(parent, Vector3(0, 8, -54), 12, 2.0, Color(1.0, 0.95, 0.78), 0.7)


## Enchanted Ground — drowsy glowing arbours that tempt the pilgrim to sleep.
static func _enchanted(parent: Node3D) -> void:
	for z in [-12.0, -28.0]:
		for s in [-1.0, 1.0]:
			var x := s * 8.0
			PropKit.arch(parent, Vector3(x, 0, z), 3.0, 3.0, Color(0.5, 0.46, 0.4), "wood")
			# leafy bower roof + an inviting soft glow and bench
			parent.add_child(_mi(_dome(2.2), MaterialKit.make("foliage", Color(0.4, 0.5, 0.38)), Vector3(x, 3.4, z)))
			parent.add_child(_mi(_box(Vector3(2.4, 0.4, 0.8)), MaterialKit.make("wood", Color(0.45, 0.38, 0.3)), Vector3(x, 0.5, z)))
			var lull := OmniLight3D.new()
			lull.position = Vector3(x, 2.2, z)
			lull.light_color = Color(0.7, 0.62, 0.8)
			lull.light_energy = 1.6
			lull.omni_range = 7.0
			parent.add_child(lull)
	_embers(parent, Vector3(0, 3, -20), Vector3(24, 4, 30), Color(0.8, 0.72, 0.85))


## Wilderness Road — a vast austere emptiness: distant mesas, scattered boulders
## and bleached bones, a lonely far goal. (Narrow ground x±6.)
static func _wilderness(parent: Node3D) -> void:
	var rng := _rng(501)
	var stone := MaterialKit.make("dry_earth", Color(0.55, 0.48, 0.38))
	# Flat-topped mesas on the far horizon.
	for i in range(5):
		var x := rng.randf_range(-22, 22)
		var z := rng.randf_range(-46, -64)
		var w := rng.randf_range(8, 16)
		var h := rng.randf_range(8, 16)
		parent.add_child(_mi(_box(Vector3(w, h, w * 0.8)), stone, Vector3(x, h * 0.5, z)))
	# Boulders and bleached bones beside the road.
	for i in range(8):
		var x := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(8, 16)
		PropKit.rock(parent, Vector3(x, 0, rng.randf_range(-38, 4)), rng.randf_range(0.8, 2.2), Color(0.56, 0.5, 0.42), "dry_earth", rng.randi())
	# A faint distant goal.
	_ray(parent, Vector3(0, 7, -58), 14, 2.2, Color(1.0, 0.96, 0.82), 0.6)


## River of Death — the far shore in glory: shining figures, beams of light, and
## an animated shimmer over the crossing. (Chapter builds the river + banks.)
static func _river(parent: Node3D) -> void:
	# Animated shimmer just above the chapter's still water (river centre z=-7).
	_water(parent, Vector3(0, 0.12, -7), Vector2(30, 26), Color(0.5, 0.62, 0.72), Color(0.12, 0.2, 0.3), 0.55)
	# The shining hosts waiting on the far bank (z=-24 .. beyond).
	for x in [-6.0, -2.0, 2.0, 6.0]:
		parent.add_child(_mi(_cone(0.0, 0.6, 3.4, 8), _emit(Color(1.0, 0.96, 0.8), 2.2, true), Vector3(x, 1.7, -32)))
	# Glory beams over the far shore.
	_ray(parent, Vector3(0, 12, -34), 22, 5, Color(1.0, 0.96, 0.82), 1.0)
	_ray(parent, Vector3(-6, 11, -33), 18, 3, Color(1.0, 0.94, 0.78), 0.8, 0, 8)
	_ray(parent, Vector3(6, 11, -33), 18, 3, Color(1.0, 0.94, 0.78), 0.8, 0, -8)


## The Cross and the Tomb — dawn breaking in glory over the Cross. (Chapter
## builds the Cross + tomb at z=-18; this adds the radiant sky behind.)
static func _cross_dawn(parent: Node3D) -> void:
	_ray(parent, Vector3(0, 12, -24), 22, 5, Color(1.0, 0.92, 0.74), 1.1)
	_ray(parent, Vector3(-5, 11, -23), 18, 3, Color(1.0, 0.9, 0.7), 0.8, 0, 7)
	_ray(parent, Vector3(5, 11, -23), 18, 3, Color(1.0, 0.9, 0.7), 0.8, 0, -7)
	PropKit.ridge(parent, Vector3(0, 0, -40), 70, 14, Color(0.45, 0.55, 0.4), "grass", 601)
	_embers(parent, Vector3(0, 4, -18), Vector3(14, 5, 8), Color(1.0, 0.92, 0.7))


# ===========================================================================
# Shared bespoke pieces
# ===========================================================================
## Drifting glowing motes/embers over an area (positive = rising).
static func _embers(parent: Node3D, center: Vector3, extents: Vector3, color: Color) -> void:
	var p := GPUParticles3D.new()
	p.position = center
	p.amount = 50
	p.lifetime = 4.0
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extents
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.8
	mat.gravity = Vector3(0.2, 0.4, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.7
	mat.color = color
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var dmat := _emit(color, 2.4, true, 1.0)
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spr := AssetLib.particle("spark")
	if spr != null:
		dmat.albedo_texture = spr
		dmat.emission_texture = spr
	quad.material = dmat
	p.draw_pass_1 = quad
	parent.add_child(p)


## A string of little colour flags between two points (festive bunting).
static func _bunting(parent: Node3D, a: Vector3, b: Vector3, count: int) -> void:
	var rng := _rng(int(a.x * 7.0 + b.z * 3.0) + 1)
	for i in range(count):
		var t := float(i) / float(count - 1)
		var pos := a.lerp(b, t)
		pos.y -= sin(t * PI) * 0.8  # gentle sag
		var col := Color.from_hsv(rng.randf(), 0.7, 0.95)
		var flag := _mi(_box(Vector3(0.35, 0.45, 0.05)), MaterialKit.make("cloth", col, {"tint_blend": 0.8}), pos)
		parent.add_child(flag)


## A stylized crouching guardian lion.
static func _lion(parent: Node3D, pos: Vector3, yaw: float, tint: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw, 0)
	var stone := MaterialKit.make("stone", tint)
	var body := _mi(_dome(0.8), stone, Vector3(0, 0.9, 0))
	body.scale = Vector3(1.8, 1.0, 1.0)
	root.add_child(body)
	root.add_child(_mi(_dome(0.5), stone, Vector3(1.1, 1.2, 0)))  # head
	root.add_child(_mi(_box(Vector3(2.4, 0.5, 1.4)), stone, Vector3(0, 0.25, 0)))  # plinth
	for lx in [-0.5, 0.6]:
		for lz in [-0.35, 0.35]:
			root.add_child(_mi(_cone(0.16, 0.18, 0.8, 6), stone, Vector3(lx, 0.4, lz)))
	parent.add_child(root)

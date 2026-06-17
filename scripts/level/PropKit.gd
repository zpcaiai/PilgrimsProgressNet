extends RefCounted
class_name PropKit
## Stylized procedural prop library.
##
## Parametric props composed from primitives (cylinders, spheres, prisms, boxes)
## and dressed with MaterialKit PBR surfaces. Everything is built in code so the
## game needs no imported 3D model files, matching the project's existing
## "procedural, asset-optional" architecture — but with far more form than bare
## greybox boxes. Used by ChapterArtProfiles to dress each chapter's world.
##
## All builders take the parent Node3D first and a local position, return the
## created root node, and never block: lights/particles are real but cheap, and
## scatter helpers are deterministic (seeded) so a chapter looks the same each
## visit.

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func _mat(surface: String, tint: Color = Color(1, 1, 1), opts: Dictionary = {}) -> StandardMaterial3D:
	return MaterialKit.make(surface, tint, opts)


static func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


static func _cyl(radius_top: float, radius_bot: float, height: float, segs: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius_top
	c.bottom_radius = radius_bot
	c.height = height
	c.radial_segments = segs
	c.rings = 1
	return c


static func _sphere(radius: float, segs: int = 10, rings: int = 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## A static collider body wrapping one box (collision layer 1, like the world).
static func _solid_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	col.shape = shp
	body.add_child(col)
	parent.add_child(body)
	return body


# ---------------------------------------------------------------------------
# Vegetation
# ---------------------------------------------------------------------------
## A rounded broadleaf tree: bark trunk + clustered foliage spheres.
static func tree(parent: Node3D, pos: Vector3, height: float = 4.0, tint: Color = Color(1, 1, 1), seed: int = 0) -> Node3D:
	var r := _rng(seed if seed != 0 else int(pos.x * 31.0 + pos.z * 17.0) + 1)
	var root := Node3D.new()
	root.position = pos
	var trunk_h := height * 0.55
	var trunk := _mesh_node(_cyl(height * 0.06, height * 0.09, trunk_h, 7), _mat("bark", tint), Vector3(0, trunk_h * 0.5, 0))
	root.add_child(trunk)
	var leaf := _mat("foliage", tint, {"tint_blend": 0.35})
	var clusters := 3 + (r.randi() % 3)
	for i in range(clusters):
		var rad := height * r.randf_range(0.26, 0.4)
		var off := Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5)) * height * 0.22
		var cy := trunk_h + height * r.randf_range(0.1, 0.4)
		root.add_child(_mesh_node(_sphere(rad), leaf, Vector3(off.x, cy, off.z)))
	parent.add_child(root)
	return root


## A conifer: bark trunk + stacked cones.
static func pine(parent: Node3D, pos: Vector3, height: float = 5.0, tint: Color = Color(1, 1, 1), seed: int = 0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var trunk_h := height * 0.25
	root.add_child(_mesh_node(_cyl(height * 0.04, height * 0.06, trunk_h, 6), _mat("bark", tint), Vector3(0, trunk_h * 0.5, 0)))
	var leaf := _mat("foliage", tint, {"tint_blend": 0.4})
	var tiers := 4
	for i in range(tiers):
		var t := float(i) / float(tiers)
		var rad := height * (0.32 - t * 0.22)
		var ch := height * 0.3
		var cy := trunk_h + t * height * 0.62 + ch * 0.5
		root.add_child(_mesh_node(_cyl(0.0, rad, ch, 8), leaf, Vector3(0, cy, 0)))
	parent.add_child(root)
	return root


## A low rounded shrub.
static func bush(parent: Node3D, pos: Vector3, radius: float = 0.8, tint: Color = Color(1, 1, 1), seed: int = 0) -> Node3D:
	var r := _rng(seed if seed != 0 else int(pos.x * 13.0 + pos.z * 7.0) + 1)
	var root := Node3D.new()
	root.position = pos
	var leaf := _mat("foliage", tint, {"tint_blend": 0.4})
	for i in range(3):
		var off := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)) * radius * 0.5
		root.add_child(_mesh_node(_sphere(radius * r.randf_range(0.6, 1.0)), leaf, Vector3(off.x, radius * 0.6, off.z)))
	parent.add_child(root)
	return root


## A dense grass field as a single MultiMesh (cheap; thousands of blades = 1 draw).
static func grass_field(parent: Node3D, center: Vector3, area: Vector2, count: int = 400, tint: Color = Color(1, 1, 1), seed: int = 7) -> MultiMeshInstance3D:
	var r := _rng(seed)
	var blade := QuadMesh.new()
	blade.size = Vector2(0.18, 0.5)
	blade.center_offset = Vector3(0, 0.25, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = count
	for i in range(count):
		var x := r.randf_range(-area.x * 0.5, area.x * 0.5)
		var z := r.randf_range(-area.y * 0.5, area.y * 0.5)
		var yaw := r.randf_range(0, TAU)
		var tilt := r.randf_range(-0.2, 0.2)
		var sc := r.randf_range(0.7, 1.4)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		basis = basis.scaled(Vector3(sc, sc, sc))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, 0, z)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.position = center
	var leaf := _mat("foliage", tint, {"tint_blend": 0.3})
	leaf.billboard_keep_scale = true
	node.material_override = leaf
	parent.add_child(node)
	return node


## Tall marsh reeds (thin cylinders) for swamps and riverbanks.
static func reeds(parent: Node3D, center: Vector3, area: Vector2, count: int = 40, tint: Color = Color(1, 1, 1), seed: int = 11) -> Node3D:
	var r := _rng(seed)
	var root := Node3D.new()
	root.position = center
	var m := _mat("foliage", tint, {"tint_blend": 0.5})
	for i in range(count):
		var x := r.randf_range(-area.x * 0.5, area.x * 0.5)
		var z := r.randf_range(-area.y * 0.5, area.y * 0.5)
		var h := r.randf_range(1.0, 2.2)
		var blade := _mesh_node(_cyl(0.0, 0.04, h, 4), m, Vector3(x, h * 0.5, z))
		blade.rotation_degrees = Vector3(r.randf_range(-8, 8), r.randf_range(0, 360), r.randf_range(-8, 8))
		root.add_child(blade)
	parent.add_child(root)
	return root


# ---------------------------------------------------------------------------
# Rock & terrain
# ---------------------------------------------------------------------------
## A single boulder (squashed, tilted sphere) with collision.
static func rock(parent: Node3D, pos: Vector3, size: float = 1.2, tint: Color = Color(1, 1, 1), surface: String = "stone", seed: int = 0) -> StaticBody3D:
	var r := _rng(seed if seed != 0 else int(pos.x * 19.0 + pos.z * 23.0) + 1)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, size * 0.35, 0)
	var sx := size * r.randf_range(0.8, 1.3)
	var sy := size * r.randf_range(0.6, 0.95)
	var sz := size * r.randf_range(0.8, 1.3)
	var mi := _mesh_node(_sphere(0.5, 8, 5), _mat(surface, tint), Vector3.ZERO)
	mi.scale = Vector3(sx, sy, sz)
	mi.rotation_degrees = Vector3(r.randf_range(-12, 12), r.randf_range(0, 360), r.randf_range(-12, 12))
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shp := SphereShape3D.new()
	shp.radius = size * 0.5
	col.shape = shp
	body.add_child(col)
	parent.add_child(body)
	return body


## A scattered cluster of boulders of mixed sizes.
static func boulder_cluster(parent: Node3D, center: Vector3, count: int = 5, scale: float = 1.4, tint: Color = Color(1, 1, 1), surface: String = "stone", seed: int = 5) -> Node3D:
	var r := _rng(seed)
	var root := Node3D.new()
	root.position = center
	for i in range(count):
		var off := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)) * scale * 1.6
		rock(root, off, scale * r.randf_range(0.5, 1.2), tint, surface, r.randi())
	parent.add_child(root)
	return root


## A craggy cliff / mountain mass — overlapping tilted stone blocks, collidable.
static func cliff(parent: Node3D, pos: Vector3, size: Vector3, tint: Color = Color(1, 1, 1), surface: String = "stone", seed: int = 3) -> Node3D:
	var r := _rng(seed)
	var root := Node3D.new()
	root.position = pos
	var m := _mat(surface, tint, {"triplanar": true})
	var chunks := 4 + (r.randi() % 3)
	for i in range(chunks):
		var cs := Vector3(size.x * r.randf_range(0.4, 0.8), size.y * r.randf_range(0.5, 1.0), size.z * r.randf_range(0.4, 0.8))
		var off := Vector3(r.randf_range(-1, 1) * size.x * 0.3, cs.y * 0.5, r.randf_range(-1, 1) * size.z * 0.3)
		var body := _solid_box(root, cs, off, m)
		body.rotation_degrees = Vector3(r.randf_range(-6, 6), r.randf_range(-20, 20), r.randf_range(-6, 6))
	parent.add_child(root)
	return root


## A distant non-colliding mountain ridge silhouette (backdrop depth).
static func ridge(parent: Node3D, center: Vector3, length: float, height: float, tint: Color = Color(1, 1, 1), surface: String = "stone", seed: int = 9) -> Node3D:
	var r := _rng(seed)
	var root := Node3D.new()
	root.position = center
	var m := _mat(surface, tint, {"triplanar": true, "tint_blend": 0.6})
	var peaks := int(length / 8.0) + 2
	for i in range(peaks):
		var t := float(i) / float(maxi(1, peaks - 1)) - 0.5
		var h := height * r.randf_range(0.6, 1.0)
		var w := length / float(peaks) * r.randf_range(1.2, 1.8)
		var cone := _mesh_node(_cyl(0.0, w * 0.5, h, 5), m, Vector3(t * length, h * 0.5, r.randf_range(-3, 3)))
		cone.rotation_degrees = Vector3(0, r.randf_range(0, 60), 0)
		root.add_child(cone)
	parent.add_child(root)
	return root


# ---------------------------------------------------------------------------
# Built structures
# ---------------------------------------------------------------------------
## A narrow gate in a short wall — the Wicket Gate motif.
static func gate(parent: Node3D, pos: Vector3, tint: Color = Color(1, 1, 1), open: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var stone := _mat("stone", tint)
	var wood := _mat("wood", tint, {"tint_blend": 0.3})
	# Posts.
	_solid_box(root, Vector3(0.6, 3.0, 0.6), Vector3(-1.1, 1.5, 0), stone)
	_solid_box(root, Vector3(0.6, 3.0, 0.6), Vector3(1.1, 1.5, 0), stone)
	# Lintel.
	_solid_box(root, Vector3(3.0, 0.5, 0.6), Vector3(0, 3.1, 0), stone)
	# Door leaf (slightly ajar if open).
	var door := _mesh_node(_box(Vector3(1.5, 2.5, 0.16)), wood, Vector3(0, 1.3, 0))
	if open:
		door.rotation_degrees = Vector3(0, 32, 0)
		door.position = Vector3(-0.6, 1.3, 0.3)
	root.add_child(door)
	parent.add_child(root)
	return root


## A stone archway (two pillars + curved-look top of stacked blocks).
static func arch(parent: Node3D, pos: Vector3, width: float = 3.0, height: float = 4.0, tint: Color = Color(1, 1, 1), surface: String = "stone") -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var m := _mat(surface, tint)
	_solid_box(root, Vector3(0.7, height, 0.7), Vector3(-width * 0.5, height * 0.5, 0), m)
	_solid_box(root, Vector3(0.7, height, 0.7), Vector3(width * 0.5, height * 0.5, 0), m)
	# Stepped "voussoirs" suggesting an arch.
	var steps := 5
	for i in range(steps):
		var t := float(i) / float(steps - 1) - 0.5
		var y := height + 0.25 + (0.5 - absf(t)) * 0.9
		var bw := width / float(steps) * 1.1
		root.add_child(_mesh_node(_box(Vector3(bw, 0.5, 0.7)), m, Vector3(t * width, y, 0)))
	parent.add_child(root)
	return root


## A straight stone wall segment, collidable. axis 0 = along X, 1 = along Z.
static func wall(parent: Node3D, pos: Vector3, length: float = 6.0, height: float = 3.0, tint: Color = Color(1, 1, 1), surface: String = "stone", axis: int = 0) -> StaticBody3D:
	var size := Vector3(length, height, 0.6) if axis == 0 else Vector3(0.6, height, length)
	return _solid_box(parent, size, pos + Vector3(0, height * 0.5, 0), _mat(surface, tint, {"triplanar": true}))


## A castellated wall — wall segment topped with battlement merlons.
static func castle_wall(parent: Node3D, pos: Vector3, length: float = 8.0, height: float = 4.0, tint: Color = Color(1, 1, 1), axis: int = 0, seed: int = 2) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var m := _mat("stone", tint, {"triplanar": true})
	var size := Vector3(length, height, 0.7) if axis == 0 else Vector3(0.7, height, length)
	_solid_box(root, size, Vector3(0, height * 0.5, 0), m)
	var merlons := int(length / 1.4)
	for i in range(merlons):
		if i % 2 == 1:
			continue
		var t := float(i) / float(maxi(1, merlons - 1)) - 0.5
		var p := Vector3(t * length, height + 0.4, 0) if axis == 0 else Vector3(0, height + 0.4, t * length)
		root.add_child(_mesh_node(_box(Vector3(0.6, 0.8, 0.7)), m, p))
	parent.add_child(root)
	return root


## A small cottage / house: solid walls with a front door opening (facing +Z)
## and a pitched gable roof + chimney. Walls collide; roof and chimney are decor.
## Used for the City of Destruction village and the pilgrim's family home.
static func cottage(parent: Node3D, pos: Vector3, size: Vector3 = Vector3(5, 3.2, 5), wall: Color = Color(0.62, 0.56, 0.48), roof: Color = Color(0.34, 0.24, 0.17)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var wmat := _mat("stone", wall, {"tint_blend": 0.55})
	var w := size.x
	var h := size.y
	var d := size.z
	var t := 0.3
	_solid_box(root, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), wmat)
	_solid_box(root, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), wmat)
	_solid_box(root, Vector3(t, h, d), Vector3(w * 0.5, h * 0.5, 0), wmat)
	# Front wall with a central door opening (so the interior is visible).
	var door_w := w * 0.4
	var seg := (w - door_w) * 0.5
	_solid_box(root, Vector3(seg, h, t), Vector3(-(door_w + seg) * 0.5, h * 0.5, d * 0.5), wmat)
	_solid_box(root, Vector3(seg, h, t), Vector3((door_w + seg) * 0.5, h * 0.5, d * 0.5), wmat)
	_solid_box(root, Vector3(door_w, h * 0.28, t), Vector3(0, h - h * 0.14, d * 0.5), wmat)
	# Pitched gable roof + chimney.
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.5, h * 0.7, d + 0.5)
	root.add_child(_mesh_node(prism, _mat("wood", roof, {"tint_blend": 0.5}), Vector3(0, h + h * 0.35, 0)))
	root.add_child(_mesh_node(_box(Vector3(0.5, 1.2, 0.5)), wmat, Vector3(w * 0.28, h + h * 0.55, -d * 0.2)))
	parent.add_child(root)
	return root


## A believable multi-storey building: stone body, cornice, a grid of framed
## windows on the front (+Z), and a pitched roof. Body collides.
static func building(parent: Node3D, pos: Vector3, size: Vector3 = Vector3(8, 8, 8), wall: Color = Color(0.7, 0.66, 0.6), roof: Color = Color(0.4, 0.3, 0.22), windows: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var wmat := _mat("stone", wall, {"tint_blend": 0.5, "triplanar": true})
	_solid_box(root, size, Vector3(0, size.y * 0.5, 0), wmat)
	root.add_child(_mesh_node(_box(Vector3(size.x + 0.5, 0.5, size.z + 0.5)), wmat, Vector3(0, size.y, 0)))
	if windows:
		var glass := _mat("stone", Color(0.16, 0.14, 0.13), {"tint_blend": 0.85})
		var frame := _mat("wood", Color(0.4, 0.3, 0.2), {"tint_blend": 0.3})
		var cols := maxi(2, int(size.x / 3.0))
		var rows := maxi(1, int((size.y - 1.0) / 3.0))
		for r in range(rows):
			for c in range(cols):
				var wx := 0.0 if cols <= 1 else (float(c) / float(cols - 1) - 0.5) * (size.x - 2.2)
				var wy := 1.8 + r * 3.0
				if wy > size.y - 1.0:
					continue
				root.add_child(_mesh_node(_box(Vector3(1.3, 1.9, 0.12)), frame, Vector3(wx, wy, size.z * 0.5 + 0.02)))
				root.add_child(_mesh_node(_box(Vector3(1.0, 1.6, 0.12)), glass, Vector3(wx, wy, size.z * 0.5 + 0.07)))
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.6, size.y * 0.45, size.z + 0.6)
	root.add_child(_mesh_node(prism, _mat("wood", roof, {"tint_blend": 0.5}), Vector3(0, size.y + 0.25 + size.y * 0.225, 0)))
	parent.add_child(root)
	return root


## A run of rail fence between two points (posts + two horizontal rails).
static func _fence_line(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	var dd := a.distance_to(b)
	var n := maxi(1, int(dd / 1.4))
	for i in range(n + 1):
		parent.add_child(_mesh_node(_cyl(0.06, 0.08, 1.0, 5), m, a.lerp(b, float(i) / float(n)) + Vector3(0, 0.5, 0)))
	var mid := (a + b) * 0.5
	var horiz := absf(b.x - a.x) > absf(b.z - a.z)
	for ry in [0.35, 0.72]:
		var rs := Vector3(dd, 0.07, 0.07) if horiz else Vector3(0.07, 0.07, dd)
		parent.add_child(_mesh_node(_box(rs), m, mid + Vector3(0, ry, 0)))


## A rectangular fenced enclosure (sheepfold) with a gap on the front (+Z).
static func pen(parent: Node3D, center: Vector3, size: Vector2, tint: Color = Color(0.46, 0.35, 0.24)) -> Node3D:
	var root := Node3D.new()
	root.position = center
	var m := _mat("wood", tint, {"tint_blend": 0.4})
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	_fence_line(root, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), m)
	_fence_line(root, Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), m)
	_fence_line(root, Vector3(hw, 0, -hd), Vector3(hw, 0, hd), m)
	_fence_line(root, Vector3(-hw, 0, hd), Vector3(-1.2, 0, hd), m)
	_fence_line(root, Vector3(1.2, 0, hd), Vector3(hw, 0, hd), m)
	parent.add_child(root)
	return root


## A stone gatehouse: two crenellated towers with an arched opening and a
## wooden door (ajar if open). The opening (~3.8m) is walkable.
static func gatehouse(parent: Node3D, pos: Vector3, tint: Color = Color(0.52, 0.48, 0.43), open: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var stone := _mat("stone", tint, {"triplanar": true})
	_solid_box(root, Vector3(2.2, 7, 2.4), Vector3(-3, 3.5, 0), stone)
	_solid_box(root, Vector3(2.2, 7, 2.4), Vector3(3, 3.5, 0), stone)
	for tx in [-3.0, 3.0]:
		for mx in [-0.6, 0.0, 0.6]:
			root.add_child(_mesh_node(_box(Vector3(0.5, 0.7, 0.5)), stone, Vector3(tx + mx, 7.4, 0)))
	for i in range(5):
		var t := float(i) / 4.0 - 0.5
		var y := 5.2 + (0.5 - absf(t)) * 1.1
		root.add_child(_mesh_node(_box(Vector3(1.3, 0.5, 2.4)), stone, Vector3(t * 4.0, y, 0)))
	var door := _mesh_node(_box(Vector3(2.0, 4.4, 0.18)), _mat("wood", tint, {"tint_blend": 0.2}), Vector3(0, 2.2, 0))
	if open:
		door.rotation_degrees = Vector3(0, 30, 0)
		door.position = Vector3(-0.7, 2.2, 0.5)
	root.add_child(door)
	parent.add_child(root)
	return root


## A classical column: base + shaft + capital.
static func pillar(parent: Node3D, pos: Vector3, height: float = 4.0, tint: Color = Color(1, 1, 1), surface: String = "marble") -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var m := _mat(surface, tint)
	root.add_child(_mesh_node(_box(Vector3(0.9, 0.3, 0.9)), m, Vector3(0, 0.15, 0)))
	root.add_child(_mesh_node(_cyl(0.32, 0.38, height - 0.6, 12), m, Vector3(0, height * 0.5, 0)))
	root.add_child(_mesh_node(_box(Vector3(0.9, 0.3, 0.9)), m, Vector3(0, height - 0.15, 0)))
	parent.add_child(root)
	return root


## The Cross — two timber beams; optionally haloed with a warm light.
static func cross(parent: Node3D, pos: Vector3, height: float = 4.0, tint: Color = Color(1, 1, 1), glow: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var wood := _mat("wood", tint, {"tint_blend": 0.2, "roughness": 0.7})
	root.add_child(_mesh_node(_box(Vector3(0.34, height, 0.34)), wood, Vector3(0, height * 0.5, 0)))
	root.add_child(_mesh_node(_box(Vector3(height * 0.55, 0.34, 0.34)), wood, Vector3(0, height * 0.72, 0)))
	if glow:
		var halo := OmniLight3D.new()
		halo.position = Vector3(0, height * 0.72, 0)
		halo.light_color = Color(1.0, 0.92, 0.7)
		halo.light_energy = 3.0
		halo.omni_range = 12.0
		root.add_child(halo)
	parent.add_child(root)
	return root


## A stone tomb chest with its great round stone rolled aside.
static func tomb(parent: Node3D, pos: Vector3, tint: Color = Color(1, 1, 1)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var m := _mat("stone", tint, {"triplanar": true})
	_solid_box(root, Vector3(2.6, 1.4, 1.6), Vector3(0, 0.7, 0), m)
	# A dark mouth (empty tomb).
	var mouth := _mat("ash", Color(0.1, 0.1, 0.12), {"tint_blend": 0.7})
	root.add_child(_mesh_node(_box(Vector3(1.2, 0.9, 0.2)), mouth, Vector3(0, 0.7, 0.81)))
	# Rolled-aside stone.
	var stone := _mesh_node(_sphere(0.85, 10, 7), m, Vector3(2.4, 0.7, 0.4))
	stone.scale = Vector3(1.0, 0.9, 1.0)
	root.add_child(stone)
	parent.add_child(root)
	return root


## A banner on a pole (cloth quad).
static func banner(parent: Node3D, pos: Vector3, height: float = 4.0, tint: Color = Color(0.7, 0.2, 0.2), seed: int = 0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_child(_mesh_node(_cyl(0.05, 0.06, height, 6), _mat("wood"), Vector3(0, height * 0.5, 0)))
	var cloth := _mat("cloth", tint, {"tint_blend": 0.6})
	var flag := _mesh_node(_box(Vector3(1.2, 1.6, 0.05)), cloth, Vector3(0.66, height - 1.0, 0))
	root.add_child(flag)
	parent.add_child(root)
	return root


## A market stall: posts, striped cloth canopy, a goods table. Vanity Fair.
static func market_stall(parent: Node3D, pos: Vector3, tint: Color = Color(1, 1, 1), cloth_color: Color = Color(0.7, 0.2, 0.25)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var wood := _mat("wood", tint, {"tint_blend": 0.2})
	for sx in [-1.4, 1.4]:
		for sz in [-0.9, 0.9]:
			_solid_box(root, Vector3(0.14, 2.2, 0.14), Vector3(sx, 1.1, sz), wood)
	# Canopy.
	var canopy := _mesh_node(_box(Vector3(3.4, 0.12, 2.4)), _mat("cloth", cloth_color, {"tint_blend": 0.7}), Vector3(0, 2.3, 0))
	canopy.rotation_degrees = Vector3(6, 0, 0)
	root.add_child(canopy)
	# Table + goods.
	_solid_box(root, Vector3(3.0, 0.16, 1.8), Vector3(0, 1.0, 0), wood)
	var goods := _mat("gold", Color(1, 1, 1))
	var r := _rng(int(pos.x * 7.0 + pos.z * 5.0) + 1)
	for i in range(5):
		root.add_child(_mesh_node(_box(Vector3(0.3, 0.3, 0.3)), goods, Vector3(r.randf_range(-1.2, 1.2), 1.25, r.randf_range(-0.6, 0.6))))
	parent.add_child(root)
	return root


## A simple sheep (Delectable Mountains): woolly body + dark head and legs.
static func sheep(parent: Node3D, pos: Vector3, seed: int = 0) -> Node3D:
	var r := _rng(seed if seed != 0 else int(pos.x * 11.0 + pos.z * 13.0) + 1)
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, r.randf_range(0, 360), 0)
	var wool := _mat("cloth", Color(0.92, 0.9, 0.86), {"tint_blend": 0.5, "roughness": 0.98})
	var dark := _mat("cloth", Color(0.2, 0.18, 0.17), {"tint_blend": 0.6})
	var body := _mesh_node(_sphere(0.45, 8, 6), wool, Vector3(0, 0.6, 0))
	body.scale = Vector3(1.4, 1.0, 1.0)
	root.add_child(body)
	root.add_child(_mesh_node(_sphere(0.2, 7, 5), dark, Vector3(0.62, 0.7, 0)))
	for lx in [-0.3, 0.3]:
		for lz in [-0.2, 0.2]:
			root.add_child(_mesh_node(_cyl(0.05, 0.05, 0.45, 5), dark, Vector3(lx, 0.22, lz)))
	parent.add_child(root)
	return root


# ---------------------------------------------------------------------------
# Light, fire, atmosphere
# ---------------------------------------------------------------------------
## A lamp on a post: warm emissive globe + an omni light.
static func lantern_post(parent: Node3D, pos: Vector3, tint: Color = Color(1, 1, 1), color: Color = Color(1.0, 0.85, 0.55), height: float = 2.6) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_child(_mesh_node(_cyl(0.05, 0.07, height, 6), _mat("wood", tint), Vector3(0, height * 0.5, 0)))
	var globe := _mat("cloth", color, {"tint_blend": 0.8, "emission": 3.0})
	root.add_child(_mesh_node(_sphere(0.22, 8, 6), globe, Vector3(0, height + 0.1, 0)))
	var light := OmniLight3D.new()
	light.position = Vector3(0, height + 0.1, 0)
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = 8.0
	root.add_child(light)
	parent.add_child(root)
	return root


## A flame: rising ember particles + a flickering warm light.
static func fire(parent: Node3D, pos: Vector3, scale: float = 1.0, color: Color = Color(1.0, 0.55, 0.2)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = int(40 * scale)
	p.lifetime = 1.4
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 1.5 * scale
	mat.initial_velocity_max = 3.5 * scale
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.2 * scale
	mat.scale_max = 0.7 * scale
	mat.color = color
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) * scale
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = color
	dmat.emission_enabled = true
	dmat.emission = color
	dmat.emission_energy_multiplier = 3.0
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ember := AssetLib.particle("spark")
	if ember != null:
		dmat.albedo_texture = ember
		dmat.emission_texture = ember
	quad.material = dmat
	p.draw_pass_1 = quad
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0 * scale
	light.omni_range = 9.0 * scale
	light.position = Vector3(0, 0.8 * scale, 0)
	p.add_child(light)
	parent.add_child(p)
	return p


## Rising dark smoke (City of Destruction). Pure particles, no light.
static func smoke(parent: Node3D, pos: Vector3, scale: float = 1.0, color: Color = Color(0.12, 0.11, 0.12)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = int(30 * scale)
	p.lifetime = 4.0
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, 1, 0)
	mat.spread = 22.0
	mat.initial_velocity_min = 1.0 * scale
	mat.initial_velocity_max = 2.5 * scale
	mat.gravity = Vector3(0.3, 0.6, 0)
	mat.scale_min = 1.5 * scale
	mat.scale_max = 4.0 * scale
	mat.color = Color(color.r, color.g, color.b, 0.5)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0) * scale
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var soft := AssetLib.particle("soft")
	if soft != null:
		dmat.albedo_texture = soft
	quad.material = dmat
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p


## Low drifting ground mist over an area (Slough, Enchanted Ground, the Valley).
static func mist(parent: Node3D, center: Vector3, area: Vector2, height: float = 1.4, color: Color = Color(0.7, 0.72, 0.75), seed: int = 4) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = center + Vector3(0, height * 0.5, 0)
	p.amount = 26
	p.lifetime = 9.0
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area.x * 0.5, height * 0.5, area.y * 0.5)
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.4
	mat.gravity = Vector3.ZERO
	mat.scale_min = 4.0
	mat.scale_max = 9.0
	mat.color = Color(color.r, color.g, color.b, 0.22)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(color.r, color.g, color.b, 0.18)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var soft := AssetLib.particle("soft")
	if soft != null:
		dmat.albedo_texture = soft
	quad.material = dmat
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p


## A volumetric-looking shaft of light (translucent emissive cone). Forward+
## gets true volumetric fog from the environment; this reads on every backend.
static func light_shaft(parent: Node3D, pos: Vector3, length: float = 14.0, radius: float = 3.0, color: Color = Color(1.0, 0.93, 0.7)) -> MeshInstance3D:
	var cone := _cyl(0.3, radius, length, 16)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.10)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := _mesh_node(cone, m, pos)
	parent.add_child(mi)
	return mi


## A still water surface (river/pool). Painterly translucent PBR plane.
static func water_plane(parent: Node3D, center: Vector3, size: Vector2, tint: Color = Color(1, 1, 1)) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var mi := _mesh_node(plane, _mat("water", tint), center)
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Scatter dispatcher (lets ChapterArtProfiles stay pure data)
# ---------------------------------------------------------------------------
## Place `count` instances of `kind` randomly within an XZ area around center.
## kind: tree, pine, bush, rock, reed_clump, sheep, lantern.
static func scatter(parent: Node3D, kind: String, center: Vector3, area: Vector2, count: int, tint: Color = Color(1, 1, 1), seed: int = 1) -> void:
	var r := _rng(seed)
	for i in range(count):
		var x := center.x + r.randf_range(-area.x * 0.5, area.x * 0.5)
		var z := center.z + r.randf_range(-area.y * 0.5, area.y * 0.5)
		var p := Vector3(x, center.y, z)
		var s := r.randi()
		match kind:
			"tree":
				tree(parent, p, r.randf_range(3.0, 5.5), tint, s)
			"pine":
				pine(parent, p, r.randf_range(4.0, 6.5), tint, s)
			"bush":
				bush(parent, p, r.randf_range(0.6, 1.1), tint, s)
			"rock":
				rock(parent, p, r.randf_range(0.6, 1.8), tint, "stone", s)
			"sheep":
				sheep(parent, p, s)
			"lantern":
				lantern_post(parent, p, tint)
			_:
				rock(parent, p, 1.0, tint, "stone", s)

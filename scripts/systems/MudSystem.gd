extends Node3D
class_name MudSystem
## The Slough of Despond's "really a swamp" layer, added by GlbChapter for
## slough_of_despond AFTER the GLB is bound. Four effects, all web/gl_compatible
## (CPUParticles3D, no compute shaders):
##   1. drifting ground MIST hanging over the mire,
##   2. rising, popping mud BUBBLES on the bog and pools,
##   3. real SINKING — the pilgrim's body dips into the muck while in a MudZone
##      (shallow vs. deep), driven from mud-zone occupancy via set_sink_depth,
##   4. sinking, fading FOOTPRINTS pressed into the mud as he wades.
## Purely a juice layer: the MudZone hazards still own the slow + despair ticks.

const SINK_SHALLOW := 0.26
const SINK_DEEP := 0.52
const STEP_DIST := 0.82          # metres between footprints
const FOOT_LIFE := 5.5

var _player: PlayerController = null
var _last_foot_pos: Vector3 = Vector3.ZERO
var _foot_left: bool = true
var _foot_primed: bool = false


func _ready() -> void:
	_boost_bog_fog()
	_spawn_ambient_fx()


# --- Ambient atmosphere -----------------------------------------------------
func _boost_bog_fog() -> void:
	# Denser, colder, greener fog so the hollow feels drowned (the GlbChapter
	# pass already enabled a light fog; we just thicken + tint it for the bog).
	var env := _find_environment()
	if env == null:
		return
	env.fog_enabled = true
	env.fog_density = 0.026
	env.fog_light_color = Color(0.46, 0.5, 0.46)
	env.fog_sky_affect = 0.3


func _spawn_ambient_fx() -> void:
	# Ground mist drifting the length of the mire.
	for p in [Vector3(0, 0.5, -6), Vector3(0, 0.5, -22), Vector3(0, 0.5, -38)]:
		_spawn_mist(p, Vector3(12, 0.4, 12))
	# Rising bubbles on the deep bog and the side pools (plus any GLB markers).
	# Kept off the central stone path (|x| >= 2.5) so bubbles rise from the muck.
	var bubble_spots := [Vector3(-2.5, 0.2, -26), Vector3(2.5, 0.2, -30),
		Vector3(-3, 0.2, -22), Vector3(-7, 0.2, -14), Vector3(7, 0.2, -34),
		Vector3(-9, 0.2, 4), Vector3(9, 0.2, 0)]
	for marker in _markers_named("VFX_MudBubbles"):
		bubble_spots.append(marker)
	for p in bubble_spots:
		_spawn_bubbles(p)


func _spawn_mist(pos: Vector3, extents: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 30.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.62, 0.66, 0.62, 0.07)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = m
	p.mesh = qm
	add_child(p)
	p.global_position = pos


func _spawn_bubbles(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.8
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.6, 0.05, 1.6)
	p.direction = Vector3(0, 1, 0)
	p.spread = 8.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 6
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.2, 0.14)
	m.roughness = 0.3
	m.metallic = 0.1
	sm.material = m
	p.mesh = sm
	add_child(p)
	p.global_position = pos


# --- Per-frame sinking + footprints ----------------------------------------
func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	# Deepest mud the pilgrim currently stands in.
	var sink := 0.0
	for z in get_tree().get_nodes_in_group("mud_zone"):
		if z is MudZone and (z as MudZone).is_occupied():
			sink = maxf(sink, SINK_DEEP if (z as MudZone).is_deep else SINK_SHALLOW)
	_player.set_sink_depth(sink)

	var pos := _player.global_position
	if sink <= 0.0:
		_foot_primed = false
		return
	if not _foot_primed:
		_foot_primed = true
		_last_foot_pos = pos
		return
	var flat := Vector3(pos.x - _last_foot_pos.x, 0.0, pos.z - _last_foot_pos.z)
	if flat.length() >= STEP_DIST:
		var dir := flat.normalized()
		_drop_footprint(pos, dir, sink >= SINK_DEEP)
		_last_foot_pos = pos
		_foot_left = not _foot_left


func _drop_footprint(pos: Vector3, dir: Vector3, deep: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.05, 0.34)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.08, 0.06, 0.9)
	mat.roughness = 0.32          # wet sheen
	mat.metallic = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Place at the pilgrim's foot, offset to the correct side of his stride.
	var side := Vector3(-dir.z, 0.0, dir.x) * (0.18 if _foot_left else -0.18)
	var base_y := pos.y + 0.03
	mi.global_position = Vector3(pos.x, base_y, pos.z) + side
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.scale = Vector3(0.4, 1.0, 0.4)
	# Press in, hold while slowly sinking, then let the mud close over it.
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "global_position:y", base_y - (0.16 if deep else 0.09), FOOT_LIFE)
	tw.tween_property(mat, "albedo_color", Color(0.07, 0.08, 0.06, 0.0), 1.4)
	tw.tween_callback(mi.queue_free)


# --- Helpers ----------------------------------------------------------------
func _find_player() -> PlayerController:
	for n in get_tree().get_nodes_in_group("player"):
		if n is PlayerController:
			return n
	return null


func _find_environment() -> Environment:
	var chapter := get_parent()
	if chapter == null:
		return null
	for c in chapter.get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment != null:
			return (c as WorldEnvironment).environment
	return null


## World positions of any GLB marker nodes whose name starts with `prefix`.
func _markers_named(prefix: String) -> Array:
	var out: Array = []
	var chapter := get_parent()
	if chapter == null:
		return out
	for n in chapter.find_children(prefix + "*", "Node3D", true, false):
		if n is Node3D:
			out.append((n as Node3D).global_position)
	return out

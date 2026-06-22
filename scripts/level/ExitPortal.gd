extends Node3D
class_name ExitPortal
## A vivid, animated chapter-exit portal so the way onward is unmistakable:
## a slowly spinning ground ring, a soft vertical light-beam, rising motes
## (CPUParticles3D -- web/gl_compatibility safe), and a gently pulsing glow.
## Purely cosmetic; the actual transition is handled by the ChapterExitTrigger
## placed at the same spot.

var _ring: MeshInstance3D
var _lamp: OmniLight3D
var _t := 0.0


func _glow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.62, 0.86, 1.0, 0.6)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.8, 1.0)
	m.emission_energy_multiplier = 5.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ready() -> void:
	var mat := _glow_mat()

	# Spinning ground ring (TorusMesh lies flat in the XZ plane by default).
	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.2
	_ring.mesh = tor
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position = Vector3(0, 0.12, 0)

	# Soft vertical light-beam.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 6.0
	beam.mesh = cyl
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.position = Vector3(0, 3.0, 0)

	# Rising motes from a ring around the base.
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 2.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0, 1, 0)
	p.emission_ring_radius = 1.05
	p.emission_ring_inner_radius = 0.8
	p.emission_ring_height = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 6.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.11
	p.color = Color(0.78, 0.92, 1.0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(0.82, 0.93, 1.0, 0.85)
	dm.emission_enabled = true
	dm.emission = Color(0.6, 0.85, 1.0)
	dm.emission_energy_multiplier = 3.0
	qm.material = dm
	p.mesh = qm
	add_child(p)
	p.position = Vector3(0, 0.2, 0)

	# Gently pulsing glow.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.6, 0.8, 1.0)
	_lamp.light_energy = 2.0
	_lamp.omni_range = 9.0
	add_child(_lamp)
	_lamp.position = Vector3(0, 2.0, 0)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_ring):
		_ring.rotate_y(delta * 1.1)
	if is_instance_valid(_lamp):
		_lamp.light_energy = 2.1 + sin(_t * 3.0) * 0.9

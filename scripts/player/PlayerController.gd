extends CharacterBody3D
class_name PlayerController
## Self-building third-person pilgrim controller.
## Builds its own mesh, collision, camera and interactor in _ready(), so no
## scene wiring is required. Movement speed is modulated by the spiritual state
## (burden + despair slow the pilgrim down).

@export var base_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var rotation_speed: float = 10.0

var control_locked: bool = false
var terrain_multiplier: float = 1.0  # set by hazards (mud, etc.)
var _mesh_root: Node3D
var _body_mesh: MeshInstance3D
var _burden_root: Node3D
var _burden_sack: MeshInstance3D = null
var _burden_tint_t: float = 0.0
var _battle_gear_root: Node3D
var _battle_gear_nodes: Array[Node3D] = []
var _is_greybox: bool = false
var _fig: Node3D
var _humanoid_animator: HumanoidAnimator = null
var _vanity_root: Node3D
var _camera: Camera3D
var _interactor: Area3D
var _current_target: Interactable = null
var _breath_timer: float = 0.0
var _glancing: bool = false
var _swimming: bool = false
var _sink_depth: float = 0.0  # current mud sink (visual), driven by MudSystem
var _target_sink_depth: float = 0.0
var _mud_struggling: bool = false
# Footstep / landing dust
var _dust: CPUParticles3D
var _land_puff: CPUParticles3D
var _was_on_floor: bool = true
var _fall_speed: float = 0.0

# Camera orbit (right-mouse drag / right stick) + look settings
@export var mouse_sensitivity: float = 0.25
@export var controller_look_sensitivity: float = 150.0
var invert_look_y: bool = false
var _cam_pivot: Node3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _looking_mouse: bool = false
const CAM_BASE_PITCH := -34.0
const CAM_PITCH_MIN := -18.0
const CAM_PITCH_MAX := 22.0

# --- camera feel (2026 pass) -------------------------------------------------
# The camera used to be a rigid grandchild of the player: no collision, no
# damping, no lead, one fixed FOV, one fixed distance. It read as a webcam
# bolted to the pilgrim's back, and it clipped straight through castle walls.
# It now hangs off a SpringArm3D (walls push it in), lags the player slightly,
# leads the travel direction, and breathes its FOV with speed and situation.
const CAM_ARM_LENGTH := 10.2
const CAM_ARM_HEIGHT := 2.35
const CAM_SHOULDER := 0.55        # lateral offset — off-centre framing
const CAM_FOLLOW_LAG := 9.0       # higher = tighter
const CAM_LEAD := 1.4             # metres of look-ahead at full speed
const FOV_BASE := 68.0
const FOV_RUN := 74.0
const FOV_TALK := 58.0
var _cam_arm: SpringArm3D
var _cam_lead: Vector3 = Vector3.ZERO
var _fov_target: float = FOV_BASE
var _cine_weight: float = 0.0     # 1.0 = fully on a cinematic marker
var _cine_cam: Camera3D = null
var _cine_from: Transform3D = Transform3D.IDENTITY
var _cine_to: Transform3D = Transform3D.IDENTITY
var _cine_time: float = 0.0
var _cine_dur: float = 0.0
var _cam_snapped: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	add_to_group("player")
	_ensure_inputs()
	_build()


func _ensure_inputs() -> void:
	# Fallback so the controller works even when a scene is run standalone.
	var defs := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
	}
	for action in defs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for keycode in defs[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action, ev)
	EventBus.player_control_locked.connect(_on_control_locked)
	EventBus.burden_removed.connect(_on_burden_removed)
	if EventBus.has_signal("chapter_started"):
		EventBus.chapter_started.connect(_on_chapter_started)
	_update_burden_visual()
	_load_input_settings()
	if EventBus.has_signal("settings_changed"):
		EventBus.settings_changed.connect(_load_input_settings)


func _build() -> void:
	# Collision capsule
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	# Mesh root (this rotates to face movement; the body itself does not)
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)

	# The pilgrim is now a real in-engine 3D body that walks on two legs. `self`
	# is the mover whose horizontal motion drives the walk cycle (the legs swing
	# in alternation via HumanoidAnimator). The greybox capsule is kept but
	# permanently hidden as a last-ditch fallback only.
	_body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	_body_mesh.mesh = capsule
	_body_mesh.position = Vector3(0, 0.9, 0)
	_body_mesh.material_override = _make_material(Color(0.78, 0.68, 0.5))
	_body_mesh.visible = false
	_mesh_root.add_child(_body_mesh)

	_fig = FigureFactory.make("Pilgrim", 2.0, self)
	_mesh_root.add_child(_fig)

	# A short beard makes the protagonist read clearly as a person while keeping
	# both hands free for the walk cycle.
	var beard := MeshInstance3D.new()
	var beard_mesh := SphereMesh.new()
	beard_mesh.radius = 0.12
	beard_mesh.height = 0.24
	beard.mesh = beard_mesh
	beard.scale = Vector3(1.0, 0.72, 0.6)
	beard.material_override = _make_material(Color(0.3, 0.22, 0.15))
	# Parent the beard to the HEAD pivot (not the torso) so it turns with the
	# head when the pilgrim looks at whoever he is talking to. Falls back to the
	# torso, then the root, so an older figure layout still works.
	var head_node: Node3D = _fig.find_child(HumanoidFigure.N_HEAD, true, false) as Node3D
	if head_node != null:
		beard.position = Vector3(0, -0.075, 0.10)
		head_node.add_child(beard)
	else:
		beard.position = Vector3(0, 1.72, 0.12)
		var _body_node: Node3D = _fig.get_node_or_null(HumanoidFigure.N_BODY)
		if _body_node != null:
			_body_node.add_child(beard)
		else:
			_fig.add_child(beard)
	_battle_gear_root = _build_battle_gear()
	_battle_gear_root.visible = false
	_fig.add_child(_battle_gear_root)

	# Burden: a real backpack on his back that he visibly drops at the Cross.
	# The 3D body faces +Z (the travel direction), so the pack is flipped to sit
	# behind him (-Z), and shown only while the burden is still carried.
	_is_greybox = false
	_burden_root = _build_backpack()
	_burden_root.rotation.y = PI
	_burden_root.visible = SpiritualStateManager.has_burden
	_mesh_root.add_child(_burden_root)

	# Vanity trinkets bought at the fair hang on the back as visible weight.
	# Flipped with the pack so they sit behind the body (which faces +Z).
	_vanity_root = Node3D.new()
	_vanity_root.rotation.y = PI
	_mesh_root.add_child(_vanity_root)
	refresh_vanity()

	# --- follow camera --------------------------------------------------
	# The pivot is still a child of the player (so it tracks position without a
	# second transform chain), but the camera now hangs off a SpringArm3D that
	# sweeps against level geometry, so it slides in against walls instead of
	# punching through them — the fix that makes interiors like Doubting Castle
	# and the Interpreter's House actually playable.
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CameraPivot"
	_cam_pivot.position = Vector3(0, CAM_ARM_HEIGHT, 0)
	_cam_pivot.top_level = true          # damped follow, not rigid parenting
	add_child(_cam_pivot)

	_cam_arm = SpringArm3D.new()
	_cam_arm.name = "CameraArm"
	_cam_arm.spring_length = CAM_ARM_LENGTH
	_cam_arm.margin = 0.35
	# Only collide with world geometry (layer 1); never with triggers or NPCs.
	_cam_arm.collision_mask = 1
	_cam_arm.add_excluded_object(get_rid())
	_cam_arm.rotation_degrees = Vector3(CAM_BASE_PITCH, 0, 0)
	_cam_pivot.add_child(_cam_arm)

	_camera = Camera3D.new()
	_camera.position = Vector3(CAM_SHOULDER, 0, 0)
	_camera.fov = FOV_BASE
	_camera.near = 0.1
	_camera.far = 320.0
	_camera.current = true
	_cam_arm.add_child(_camera)

	# Interactor
	_interactor = Area3D.new()
	_interactor.name = "Interactor"
	_interactor.collision_layer = 0
	_interactor.collision_mask = 2
	_interactor.monitoring = true
	var icol := CollisionShape3D.new()
	var isphere := SphereShape3D.new()
	isphere.radius = 2.2
	icol.shape = isphere
	icol.position = Vector3(0, 0.9, 0)
	_interactor.add_child(icol)
	add_child(_interactor)

	_build_dust()
	_update_battle_gear_visual()


## Rebuild the hanging trinkets to match how much vanity you bought.
func refresh_vanity() -> void:
	if not is_instance_valid(_vanity_root):
		return
	for c in _vanity_root.get_children():
		c.queue_free()
	var count: int = GameState.get_item_count("vanity_token")
	var tints := [Color(0.9, 0.8, 0.2), Color(0.8, 0.2, 0.4), Color(0.5, 0.3, 0.9), Color(0.3, 0.8, 0.9)]
	for i in range(min(count, 4)):
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 0.22, 0.22)
		t.mesh = bm
		t.position = Vector3(-0.25 + (i % 2) * 0.5, 1.35 - (i / 2) * 0.45, 0.52)
		var m := _make_material(tints[i % tints.size()])
		m.emission_enabled = true
		m.emission = tints[i % tints.size()]
		m.emission_energy_multiplier = 0.6
		t.material_override = m
		_vanity_root.add_child(t)

func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func _dust_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = CharacterBillboard.soft_disc()
	q.material = m
	return q


## Little dust kicked up underfoot while walking, plus a puff when landing.
func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "FootDust"
	_dust.position = Vector3(0, 0.06, 0)
	_dust.emitting = false
	_dust.amount = 14
	_dust.lifetime = 0.7
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 0.18
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 35.0
	_dust.gravity = Vector3(0, 0.4, 0)
	_dust.initial_velocity_min = 0.2
	_dust.initial_velocity_max = 0.7
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 0.9
	_dust.color = Color(0.62, 0.55, 0.45, 0.5)
	_dust.mesh = _dust_mesh()
	add_child(_dust)

	_land_puff = CPUParticles3D.new()
	_land_puff.name = "LandPuff"
	_land_puff.position = Vector3(0, 0.06, 0)
	_land_puff.emitting = false
	_land_puff.one_shot = true
	_land_puff.amount = 18
	_land_puff.lifetime = 0.6
	_land_puff.explosiveness = 0.9
	_land_puff.local_coords = false
	_land_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_land_puff.emission_sphere_radius = 0.22
	_land_puff.direction = Vector3(0, 1, 0)
	_land_puff.spread = 70.0
	_land_puff.gravity = Vector3(0, 0.2, 0)
	_land_puff.initial_velocity_min = 0.6
	_land_puff.initial_velocity_max = 1.4
	_land_puff.scale_amount_min = 0.5
	_land_puff.scale_amount_max = 1.0
	_land_puff.color = Color(0.62, 0.55, 0.45, 0.6)
	_land_puff.mesh = _dust_mesh()
	add_child(_land_puff)


func _update_dust() -> void:
	var on_floor := is_on_floor()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_instance_valid(_dust):
		_dust.emitting = on_floor and hspeed > 1.2 and not control_locked
	if not on_floor:
		_fall_speed = -velocity.y
	if on_floor and not _was_on_floor and _fall_speed > 3.0 and is_instance_valid(_land_puff):
		_land_puff.restart()
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor


## The pilgrim is a full 3D body now: the mesh-root yaw (set in _physics_process)
## turns him to face the travel direction, so his legs stride forward and the
## back of his head shows when he walks away. The old front/back billboard swap
## is no longer needed.
func _update_facing() -> void:
	pass


func _load_input_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return
	mouse_sensitivity = float(cf.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	controller_look_sensitivity = float(cf.get_value("input", "controller_look_sensitivity", controller_look_sensitivity))
	invert_look_y = bool(cf.get_value("input", "invert_look_y", invert_look_y))


func _apply_look(dyaw: float, dpitch: float) -> void:
	_cam_yaw += dyaw
	if invert_look_y:
		dpitch = -dpitch
	_cam_pitch = clampf(_cam_pitch + dpitch, CAM_PITCH_MIN, CAM_PITCH_MAX)


func _update_camera(delta: float) -> void:
	if not control_locked and InputMap.has_action("look_left"):
		var lx := Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
		var ly := Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
		if absf(lx) > 0.05 or absf(ly) > 0.05:
			_apply_look(-lx * controller_look_sensitivity * delta, -ly * controller_look_sensitivity * delta)
	if not is_instance_valid(_cam_pivot):
		return
	if not _cam_snapped:
		snap_camera()

	# --- cinematic override (chapter establishing shot / set-piece) --------
	if _cine_weight > 0.0 or _cine_dur > 0.0:
		_update_cinematic(delta)
		return

	# --- look-ahead: the camera leads where the pilgrim is going ----------
	var flat_vel := Vector3(velocity.x, 0, velocity.z)
	var lead_target := Vector3.ZERO
	if flat_vel.length() > 0.5:
		lead_target = flat_vel.normalized() * CAM_LEAD * clampf(flat_vel.length() / 5.0, 0.0, 1.0)
	_cam_lead = _cam_lead.lerp(lead_target, clampf(delta * 3.0, 0.0, 1.0))

	# --- damped follow ----------------------------------------------------
	var anchor := global_position + Vector3(0, CAM_ARM_HEIGHT, 0) + _cam_lead
	var lag := clampf(delta * CAM_FOLLOW_LAG, 0.0, 1.0)
	_cam_pivot.global_position = _cam_pivot.global_position.lerp(anchor, lag)
	_cam_pivot.rotation.y = lerp_angle(_cam_pivot.rotation.y, deg_to_rad(_cam_yaw),
		clampf(delta * 10.0, 0.0, 1.0))

	if is_instance_valid(_cam_arm):
		_cam_arm.rotation_degrees.x = CAM_BASE_PITCH + _cam_pitch
		# Pull in a little when swimming or sunk in the mire so the pilgrim
		# stays framed rather than shrinking to a dot on a flat plane.
		var want_len := CAM_ARM_LENGTH
		if _swimming:
			want_len = CAM_ARM_LENGTH * 0.82
		elif _sink_depth > 0.15:
			want_len = CAM_ARM_LENGTH * 0.88
		_cam_arm.spring_length = lerpf(_cam_arm.spring_length, want_len,
			clampf(delta * 2.5, 0.0, 1.0))

	# --- FOV breathing ----------------------------------------------------
	if is_instance_valid(_camera):
		var want_fov := FOV_BASE
		if control_locked:
			want_fov = FOV_TALK          # conversations frame tighter
		elif flat_vel.length() > 4.0:
			want_fov = FOV_RUN           # speed opens the frame
		_fov_target = lerpf(_fov_target, want_fov, clampf(delta * 3.0, 0.0, 1.0))
		_camera.fov = _fov_target


## Blend to a fixed world transform for `dur` seconds, then home to gameplay.
## Used by ChapterCamera for the per-chapter establishing shot and by set-piece
## moments. A SEPARATE camera is used rather than moving the gameplay one,
## because the gameplay camera is a SpringArm3D child whose transform the arm
## rewrites every frame — driving it directly would fight the arm.
func push_cinematic(xform: Transform3D, dur: float = 4.0) -> void:
	if not is_instance_valid(_camera):
		return
	if dur <= 0.0:
		release_cinematic()
		return
	if not is_instance_valid(_cine_cam):
		_cine_cam = Camera3D.new()
		_cine_cam.name = "CinematicCamera"
		_cine_cam.top_level = true
		_cine_cam.fov = FOV_TALK
		_cine_cam.near = 0.1
		_cine_cam.far = 400.0
		add_child(_cine_cam)
	_cine_from = _camera.global_transform
	_cine_to = xform
	_cine_cam.global_transform = _cine_from
	_cine_cam.current = true
	_cine_time = 0.0
	_cine_dur = dur


## Release a cinematic shot early (player pressed a key / dialogue started).
func release_cinematic() -> void:
	if _cine_dur <= 0.0:
		return
	# Keep whatever blend-back time is left rather than snapping.
	_cine_time = maxf(_cine_time, _cine_dur * 0.78)


func is_cinematic() -> bool:
	return _cine_dur > 0.0


func _update_cinematic(delta: float) -> void:
	# Keep the gameplay rig tracking underneath so the hand-back is seamless.
	var anchor := global_position + Vector3(0, CAM_ARM_HEIGHT, 0)
	_cam_pivot.global_position = _cam_pivot.global_position.lerp(anchor,
		clampf(delta * CAM_FOLLOW_LAG, 0.0, 1.0))
	_cam_pivot.rotation.y = deg_to_rad(_cam_yaw)
	if is_instance_valid(_cam_arm):
		_cam_arm.rotation_degrees.x = CAM_BASE_PITCH + _cam_pitch

	if not is_instance_valid(_cine_cam):
		_cine_dur = 0.0
		return

	_cine_time += delta
	var t := clampf(_cine_time / maxf(_cine_dur, 0.001), 0.0, 1.0)
	# Ease off the gameplay camera, hold the shot, then ease back.
	var w := 1.0
	if t < 0.14:
		w = smoothstep(0.0, 1.0, t / 0.14)
	elif t > 0.72:
		w = 1.0 - smoothstep(0.0, 1.0, (t - 0.72) / 0.28)
	_cine_weight = w

	# A slow drift keeps the held shot alive instead of a frozen postcard.
	var drift := _cine_to
	drift.origin += drift.basis.x * sin(_cine_time * 0.4) * 0.35
	drift.origin.y += sin(_cine_time * 0.27) * 0.12

	var gameplay := _camera.global_transform
	_cine_cam.global_transform = gameplay.interpolate_with(drift, w)
	_cine_cam.fov = lerpf(_camera.fov, FOV_TALK, w * 0.6)

	if t >= 1.0:
		_cine_dur = 0.0
		_cine_weight = 0.0
		_camera.current = true
		_cine_cam.queue_free()
		_cine_cam = null


func _on_control_locked(locked: bool) -> void:
	control_locked = locked
	if locked:
		velocity.x = 0
		velocity.z = 0


func _on_burden_removed() -> void:
	_update_burden_visual()


func _on_chapter_started(_chapter_id: String) -> void:
	_update_battle_gear_visual()


func _update_burden_visual() -> void:
	if is_instance_valid(_burden_root):
		_burden_root.visible = _is_greybox and SpiritualStateManager.has_burden


func _update_battle_gear_visual() -> void:
	var show := _should_show_battle_gear()
	if is_instance_valid(_battle_gear_root):
		_battle_gear_root.visible = show
	for node in _battle_gear_nodes:
		if is_instance_valid(node):
			node.visible = show


func _should_show_battle_gear() -> bool:
	var cid := String(ChapterManager.current_chapter_id)
	var start_idx := ChapterManager.get_chapter_index("valley_humiliation")
	var cur_idx := ChapterManager.get_chapter_index(cid)
	return start_idx >= 0 and cur_idx >= start_idx


func _build_battle_gear() -> Node3D:
	var root := Node3D.new()
	root.name = "BattleGear"
	var body := _fig.get_node_or_null("Body") as Node3D
	if body == null:
		return root

	var steel := _make_material(Color(0.56, 0.58, 0.61))
	steel.metallic = 0.55
	steel.roughness = 0.36
	var dark_steel := _make_material(Color(0.28, 0.31, 0.34))
	dark_steel.metallic = 0.45
	dark_steel.roughness = 0.42
	var gold := _make_material(Color(0.96, 0.72, 0.28))
	gold.metallic = 0.5
	gold.roughness = 0.38
	var crimson := _make_material(Color(0.62, 0.08, 0.06))
	var leather := _make_material(Color(0.22, 0.13, 0.07))

	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.5, 0.62, 0.1)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 1.26, 0.08)
	chest.material_override = steel
	body.add_child(chest)
	_register_battle_gear_node(chest)

	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.48, 0.56, 0.08)
	back.mesh = back_mesh
	back.position = Vector3(0, 1.26, -0.12)
	back.material_override = dark_steel
	body.add_child(back)
	_register_battle_gear_node(back)

	for x in [-0.31, 0.31]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.15
		shoulder_mesh.height = 0.18
		shoulder.mesh = shoulder_mesh
		shoulder.scale = Vector3(1.35, 0.42, 0.9)
		shoulder.position = Vector3(x, 1.56, 0.02)
		shoulder.material_override = steel
		body.add_child(shoulder)
		_register_battle_gear_node(shoulder)

	var belt := MeshInstance3D.new()
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.25
	belt_mesh.bottom_radius = 0.25
	belt_mesh.height = 0.08
	belt.mesh = belt_mesh
	belt.position = Vector3(0, 1.02, 0.0)
	belt.material_override = gold
	body.add_child(belt)
	_register_battle_gear_node(belt)

	var skirt := MeshInstance3D.new()
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.28
	skirt_mesh.bottom_radius = 0.34
	skirt_mesh.height = 0.28
	skirt.mesh = skirt_mesh
	skirt.position = Vector3(0, 0.84, 0.0)
	skirt.material_override = dark_steel
	body.add_child(skirt)
	_register_battle_gear_node(skirt)

	var helm := MeshInstance3D.new()
	var helm_mesh := SphereMesh.new()
	helm_mesh.radius = 0.19
	helm_mesh.height = 0.22
	helm.mesh = helm_mesh
	helm.scale = Vector3(1.05, 0.55, 1.0)
	helm.position = Vector3(0, 1.94, -0.01)
	helm.material_override = steel
	body.add_child(helm)
	_register_battle_gear_node(helm)

	var crest := MeshInstance3D.new()
	var crest_mesh := BoxMesh.new()
	crest_mesh.size = Vector3(0.08, 0.26, 0.24)
	crest.mesh = crest_mesh
	crest.position = Vector3(0, 2.08, -0.03)
	crest.material_override = crimson
	body.add_child(crest)
	_register_battle_gear_node(crest)

	var right_arm := body.get_node_or_null("ArmR") as Node3D
	if right_arm != null:
		var sword := _build_sword(steel, gold, leather)
		right_arm.add_child(sword)
		_register_battle_gear_node(sword)

	return root


func _register_battle_gear_node(node: Node3D) -> void:
	node.visible = false
	_battle_gear_nodes.append(node)


func _build_sword(blade_m: StandardMaterial3D, guard_m: StandardMaterial3D,
		grip_m: StandardMaterial3D) -> Node3D:
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = Vector3(0.02, -0.72, 0.06)
	sword.rotation_degrees = Vector3(-10, 0, 0)

	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.035
	grip_mesh.bottom_radius = 0.035
	grip_mesh.height = 0.24
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.08, 0)
	grip.material_override = grip_m
	sword.add_child(grip)

	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.32, 0.04, 0.06)
	guard.mesh = guard_mesh
	guard.position = Vector3(0, -0.22, 0)
	guard.material_override = guard_m
	sword.add_child(guard)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.055, 0.78, 0.035)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.63, 0)
	blade.material_override = blade_m
	sword.add_child(blade)

	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.07, 0.16, 0.04)
	tip.mesh = tip_mesh
	tip.rotation_degrees = Vector3(0, 0, 180)
	tip.position = Vector3(0, -1.1, 0)
	tip.material_override = blade_m
	sword.add_child(tip)
	return sword


## A pilgrim's backpack (rounded sack + flap + bedroll + shoulder straps) for the
## greybox fallback. The painted figure already has its own pack.
func _build_backpack() -> Node3D:
	var root := Node3D.new()
	var sack := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.42
	s.height = 0.9
	sack.mesh = s
	sack.scale = Vector3(1.0, 1.1, 0.8)
	sack.position = Vector3(0, 1.05, 0.42)
	# The burden now CARRIES WHAT YOU CARRY: the sack is tinted by whichever
	# weight dominates your spiritual state (deception violet, pride crimson,
	# shame ochre, fear blue, despair slate, weariness dun) and re-tinted as it
	# changes. It used to be the same brown box for every player in every run —
	# the most personal object in the game, rendered as the most generic one.
	sack.material_override = _make_material(BurdenColour.current())
	sack.name = "BurdenSack"
	_burden_sack = sack
	root.add_child(sack)
	var flap := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.72, 0.26, 0.6)
	flap.mesh = fb
	flap.position = Vector3(0, 1.46, 0.42)
	flap.material_override = _make_material(Color(0.34, 0.24, 0.14))
	root.add_child(flap)
	var roll := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 0.82
	roll.mesh = cyl
	roll.rotation_degrees = Vector3(0, 0, 90)
	roll.position = Vector3(0, 1.62, 0.42)
	roll.material_override = _make_material(Color(0.55, 0.45, 0.30))
	root.add_child(roll)
	for sx in [-0.18, 0.18]:
		var off := float(sx)
		var strap := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.08, 0.95, 0.06)
		strap.mesh = sb
		strap.position = Vector3(off, 1.12, -0.2)
		strap.material_override = _make_material(Color(0.3, 0.2, 0.12))
		root.add_child(strap)
	return root


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	_update_camera(delta)

	var input_dir := Vector3.ZERO
	if not control_locked:
		if InputManager and InputManager.has_method("get_movement_vector_3d"):
			input_dir = InputManager.get_movement_vector_3d(_cam_yaw)
		else:
			var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
			var z := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
			input_dir = Vector3(x, 0, z)
			if input_dir.length() > 1.0:
				input_dir = input_dir.normalized()
			# Make movement relative to where the camera is looking (orbit yaw).
			if absf(_cam_yaw) > 0.01:
				input_dir = input_dir.rotated(Vector3.UP, deg_to_rad(_cam_yaw))

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

	var speed := base_speed * SpiritualStateManager.get_movement_multiplier() * terrain_multiplier
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	# Rotate mesh toward movement
	if input_dir.length() > 0.1 and is_instance_valid(_mesh_root) and not _glancing:
		var target_yaw := atan2(input_dir.x, input_dir.z)
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target_yaw, rotation_speed * delta)

	move_and_slide()
	_update_visual_submersion(delta)
	_update_dust()
	_update_facing()
	_update_interaction()
	_update_breath(delta, input_dir.length() > 0.1)


func _update_breath(delta: float, _moving: bool) -> void:
	_update_burden_tint(delta)
	# Subtle "heavy breathing" cue while burdened: bob the body slightly.
	if not is_instance_valid(_body_mesh):
		return
	if SpiritualStateManager.has_burden:
		_breath_timer += delta * 2.0
		_body_mesh.position.y = 0.9 + sin(_breath_timer) * 0.03


## Ease the burden's colour toward whatever the pilgrim is presently carrying.
## Slow on purpose — a burden that changes hue mid-stride reads as a bug; one
## that has shifted by the time you next look at it reads as truth.
func _update_burden_tint(delta: float) -> void:
	if not is_instance_valid(_burden_sack) or not SpiritualStateManager.has_burden:
		return
	_burden_tint_t += delta
	if _burden_tint_t < 1.5:
		return
	_burden_tint_t = 0.0
	var mat := _burden_sack.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = mat.albedo_color.lerp(BurdenColour.current(), 0.35)


func _update_interaction() -> void:
	var nearest: Interactable = null
	var nearest_dist := INF
	for area in _interactor.get_overlapping_areas():
		if area is Interactable and (area as Interactable).can_interact():
			var d := global_position.distance_to(area.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = area
	if nearest != _current_target:
		_current_target = nearest
		if nearest != null:
			EventBus.interaction_available.emit(nearest.name, nearest.get_prompt())
		else:
			EventBus.interaction_unavailable.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Hold right mouse button to orbit the camera (mouse-look without grabbing
	# the cursor, so menus and clicking stay usable).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking_mouse = event.pressed
	if control_locked:
		return
	if event is InputEventMouseMotion and _looking_mouse:
		_apply_look(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	if event.is_action_pressed("interact") and _current_target != null and (not InputManager or InputManager.can_interact()):
		_current_target.interact(self)


## Briefly turn to face a point (a look-back beat), then ease back to forward.
func glance_toward(point: Vector3) -> void:
	if not is_instance_valid(_mesh_root):
		return
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var yaw := atan2(to.x, to.z)
	var start := _mesh_root.rotation.y
	_glancing = true
	var tw := create_tween()
	tw.tween_property(_mesh_root, "rotation:y", yaw, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.1)
	tw.tween_property(_mesh_root, "rotation:y", start, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _glancing = false)


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	snap_camera()


## Put the damped camera rig exactly where it belongs, with no interpolation.
## Must be called after any teleport (chapter spawn, gate passage) — otherwise
## the lagged follow swoops across the whole level to catch up.
func snap_camera() -> void:
	if not is_instance_valid(_cam_pivot):
		return
	_cam_lead = Vector3.ZERO
	_cam_pivot.global_position = global_position + Vector3(0, CAM_ARM_HEIGHT, 0)
	_cam_pivot.rotation.y = deg_to_rad(_cam_yaw)
	_cam_snapped = true


## Enter / leave the water (River of Death). While swimming, the body sinks so
## the pilgrim is submerged to the waist (the river's surface plane hides his
## legs) and the figure switches to a swim stroke. The physics capsule is left
## flush, so movement stays robust — only the visible mesh dips. Driven by
## RiverWaterZone when the player crosses into the wet stretch.
func set_swimming(on: bool) -> void:
	if on == _swimming:
		return
	_swimming = on
	if on:
		_target_sink_depth = 0.0
		set_mud_struggling(false)
	var anim := _get_humanoid_animator()
	if anim != null:
		anim.swimming = on


func is_swimming() -> bool:
	return _swimming


## Sink the pilgrim's visible body into the mud (separate from swimming). `depth`
## is in metres (0 restores). The physics capsule stays flush so movement is
## robust — only the mesh dips, so stepping into the mire really sinks you.
## Driven each frame by MudSystem from mud-zone occupancy.
func set_sink_depth(depth: float) -> void:
	if _swimming:
		return
	_target_sink_depth = maxf(0.0, depth)


## Blend the figure into the Slough's laboured swimming/struggle animation.
## Kept separate from set_swimming so the River of Death retains its crawl.
func set_mud_struggling(on: bool, intensity: float = 0.0) -> void:
	_mud_struggling = on
	var anim := _get_humanoid_animator()
	if anim != null:
		anim.mud_struggling = on
		anim.struggle_intensity = clampf(intensity, 0.0, 1.0) if on else 0.0


func is_mud_struggling() -> bool:
	return _mud_struggling


func _get_humanoid_animator() -> HumanoidAnimator:
	if is_instance_valid(_humanoid_animator):
		return _humanoid_animator
	if is_instance_valid(_fig):
		_humanoid_animator = HumanoidAnimator.find_in(_fig)
	return _humanoid_animator


func _update_visual_submersion(delta: float) -> void:
	if not is_instance_valid(_mesh_root):
		return
	var target := 0.45 if _swimming else _target_sink_depth
	_sink_depth = lerpf(_sink_depth, target, clampf(delta * 5.5, 0.0, 1.0))
	_mesh_root.position.y = -_sink_depth

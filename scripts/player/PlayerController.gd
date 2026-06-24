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
var _is_greybox: bool = false
var _fig: Node3D
var _vanity_root: Node3D
var _camera: Camera3D
var _interactor: Area3D
var _current_target: Interactable = null
var _breath_timer: float = 0.0
var _glancing: bool = false
var _swimming: bool = false
var _sink_depth: float = 0.0  # mud sink (visual), driven by MudSystem
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
const CAM_BASE_PITCH := -38.0
const CAM_PITCH_MIN := -18.0
const CAM_PITCH_MAX := 22.0


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

	_fig = HumanoidFigure.make("Pilgrim", 2.0, self)
	_mesh_root.add_child(_fig)

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

	# Fixed-orientation follow camera (child, but parented to player so it
	# tracks position; the player body never rotates, so the view stays stable)
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CameraPivot"
	add_child(_cam_pivot)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 6.5, 8.0)
	_camera.rotation_degrees = Vector3(CAM_BASE_PITCH, 0, 0)
	_camera.current = true
	_cam_pivot.add_child(_camera)

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
	if is_instance_valid(_cam_pivot):
		_cam_pivot.rotation.y = deg_to_rad(_cam_yaw)
	if is_instance_valid(_camera):
		_camera.rotation_degrees.x = CAM_BASE_PITCH + _cam_pitch


func _on_control_locked(locked: bool) -> void:
	control_locked = locked
	if locked:
		velocity.x = 0
		velocity.z = 0


func _on_burden_removed() -> void:
	_update_burden_visual()


func _update_burden_visual() -> void:
	if is_instance_valid(_burden_root):
		_burden_root.visible = _is_greybox and SpiritualStateManager.has_burden


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
	sack.material_override = _make_material(Color(0.42, 0.30, 0.18))
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
	_update_dust()
	_update_facing()
	_update_interaction()
	_update_breath(delta, input_dir.length() > 0.1)


func _update_breath(delta: float, _moving: bool) -> void:
	# Subtle "heavy breathing" cue while burdened: bob the body slightly.
	if not is_instance_valid(_body_mesh):
		return
	if SpiritualStateManager.has_burden:
		_breath_timer += delta * 2.0
		_body_mesh.position.y = 0.9 + sin(_breath_timer) * 0.03


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
	if event.is_action_pressed("interact") and _current_target != null:
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


## Enter / leave the water (River of Death). While swimming, the body sinks so
## the pilgrim is submerged to the waist (the river's surface plane hides his
## legs) and the figure switches to a swim stroke. The physics capsule is left
## flush, so movement stays robust — only the visible mesh dips. Driven by
## RiverWaterZone when the player crosses into the wet stretch.
func set_swimming(on: bool) -> void:
	if on == _swimming:
		return
	_swimming = on
	if is_instance_valid(_fig):
		var anim := HumanoidAnimator.find_in(_fig)
		if anim != null:
			anim.swimming = on
	if is_instance_valid(_mesh_root):
		var sink := -0.45 if on else 0.0
		var tw := create_tween()
		tw.tween_property(_mesh_root, "position:y", sink, 0.5).set_trans(Tween.TRANS_SINE)


func is_swimming() -> bool:
	return _swimming


## Sink the pilgrim's visible body into the mud (separate from swimming). `depth`
## is in metres (0 restores). The physics capsule stays flush so movement is
## robust — only the mesh dips, so stepping into the mire really sinks you.
## Driven each frame by MudSystem from mud-zone occupancy.
func set_sink_depth(depth: float) -> void:
	if _swimming:
		return
	if is_equal_approx(depth, _sink_depth):
		return
	_sink_depth = depth
	if is_instance_valid(_mesh_root):
		var tw := create_tween()
		tw.tween_property(_mesh_root, "position:y", -depth, 0.35).set_trans(Tween.TRANS_SINE)

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
var _burden_mesh: MeshInstance3D
var _camera: Camera3D
var _interactor: Area3D
var _current_target: Interactable = null
var _breath_timer: float = 0.0


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

	_body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	_body_mesh.mesh = capsule
	_body_mesh.position = Vector3(0, 0.9, 0)
	_body_mesh.material_override = _make_material(Color(0.78, 0.68, 0.5))
	_mesh_root.add_child(_body_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	head.mesh = sphere
	head.position = Vector3(0, 1.85, 0)
	head.material_override = _make_material(Color(0.9, 0.78, 0.62))
	_mesh_root.add_child(head)

	# Burden on the back
	_burden_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.5)
	_burden_mesh.mesh = box
	_burden_mesh.position = Vector3(0, 1.1, 0.5)
	_burden_mesh.material_override = _make_material(Color(0.25, 0.2, 0.18))
	_mesh_root.add_child(_burden_mesh)

	# Fixed-orientation follow camera (child, but parented to player so it
	# tracks position; the player body never rotates, so the view stays stable)
	var cam_pivot := Node3D.new()
	cam_pivot.name = "CameraPivot"
	add_child(cam_pivot)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 6.5, 8.0)
	_camera.rotation_degrees = Vector3(-38, 0, 0)
	_camera.current = true
	cam_pivot.add_child(_camera)

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


func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func _on_control_locked(locked: bool) -> void:
	control_locked = locked
	if locked:
		velocity.x = 0
		velocity.z = 0


func _on_burden_removed() -> void:
	_update_burden_visual()


func _update_burden_visual() -> void:
	if is_instance_valid(_burden_mesh):
		_burden_mesh.visible = SpiritualStateManager.has_burden


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector3.ZERO
	if not control_locked:
		var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var z := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		input_dir = Vector3(x, 0, z)
		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

	var speed := base_speed * SpiritualStateManager.get_movement_multiplier() * terrain_multiplier
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	# Rotate mesh toward movement
	if input_dir.length() > 0.1 and is_instance_valid(_mesh_root):
		var target_yaw := atan2(input_dir.x, input_dir.z)
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target_yaw, rotation_speed * delta)

	move_and_slide()
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
	if control_locked:
		return
	if event.is_action_pressed("interact") and _current_target != null:
		_current_target.interact(self)


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO

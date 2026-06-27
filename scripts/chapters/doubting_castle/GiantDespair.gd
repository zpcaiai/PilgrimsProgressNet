extends CharacterBody3D
class_name GiantDespair
## A real, towering Giant — Giant Despair — who prowls the dark hall of Doubting
## Castle. He is built as a ~4.8 m in-engine 3D body (HumanoidFigure, foe look)
## with a heavy knotted club, paces the bailey on two legs, lowers toward the
## pilgrim when near, and can be spoken to (his accusation). He is NOT a combat
## boss: escape is by the key called Promise, and the chapter itself presses
## despair — the Giant is the looming, oppressive presence of that despair.
##
## Spawned by ImportedSceneBinder from the NPC_GiantDespair marker.

const HEIGHT := 4.8
const PATROL_SPEED := 1.25
const STALK_SPEED := 1.7
const SIGHT := 15.0
var gravity: float = 18.0

var _fig: Node3D = null
var _club: Node3D = null
var _player: Node3D = null
var _patrol_a: Vector3
var _patrol_b: Vector3
var _to_b: bool = true
var _origin: Vector3
var _mutter: float = 0.0
var _slam_cd: float = 3.5
var _slamming: bool = false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1   # SOLID: the pilgrim bumps the Giant instead of passing through
	collision_mask = 1    # the Giant rests on the floor and is stopped by the castle walls
	_origin = global_position
	_patrol_a = _origin + Vector3(-3.5, 0, 0)
	_patrol_b = _origin + Vector3(3.5, 0, 0)
	_build_visual()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.1
	shape.height = HEIGHT
	col.shape = shape
	col.position = Vector3(0, HEIGHT * 0.5, 0)
	add_child(col)

	# The Giant's body: a huge, menacing emissive figure.
	_fig = HumanoidFigure.make("Giant Despair", HEIGHT, self, true,
		Color(0.17, 0.19, 0.25), true)
	add_child(_fig)
	_club = _make_club()
	_fig.add_child(_club)
	_add_ogre_features()

	var label := Label3D.new()
	label.text = "绝望巨人 / Giant Despair"
	label.position = Vector3(0, HEIGHT + 0.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.85, 0.7, 0.7)
	label.pixel_size = 0.012
	label.outline_size = 7
	add_child(label)

	# Talkable: his accusation in the cell. A wide reach, since he is huge.
	var talk := Interactable.new()
	talk.prompt = "听绝望巨人的控告 (Face Giant Despair)"
	talk.one_shot = false
	talk.interact_callback = func(p):
		if is_instance_valid(p) and p.has_method("glance_toward"):
			p.call("glance_toward", global_position)
		if not DialogueManager.is_active():
			DialogueManager.start_dialogue("giant_despair_accusation")
	var tcol := CollisionShape3D.new()
	var tsph := SphereShape3D.new()
	tsph.radius = 3.2
	tcol.shape = tsph
	tcol.position = Vector3(0, 1.2, 0)
	talk.add_child(tcol)
	add_child(talk)


## Brutish ogre features over the base figure — a heavy brow, a jutting tusked
## jaw, and hunched shoulder/back humps — so Giant Despair reads as a monster,
## not just a tall man. Attached to the figure's Body so they ride his motion.
func _add_ogre_features() -> void:
	var body: Node3D = _fig.get_node_or_null("Body")
	if body == null:
		return
	var s := HEIGHT / 2.0
	var head_y := 1.83 * s
	var head_r := 0.16 * s
	var shoulder_y := 1.58 * s
	var hide := _ogre_mat(Color(0.15, 0.17, 0.22))
	var tusk := _ogre_mat(Color(0.82, 0.78, 0.64))
	# heavy brow ridge
	var brow := MeshInstance3D.new()
	var brow_m := BoxMesh.new()
	brow_m.size = Vector3(head_r * 2.0, head_r * 0.5, head_r * 0.8)
	brow.mesh = brow_m
	brow.position = Vector3(0, head_y + head_r * 0.5, head_r * 0.6)
	brow.material_override = hide
	body.add_child(brow)
	# jutting lower jaw
	var jaw := MeshInstance3D.new()
	var jaw_m := BoxMesh.new()
	jaw_m.size = Vector3(head_r * 1.5, head_r * 0.7, head_r * 0.95)
	jaw.mesh = jaw_m
	jaw.position = Vector3(0, head_y - head_r * 0.7, head_r * 0.5)
	jaw.material_override = hide
	body.add_child(jaw)
	# two tusks jutting up from the jaw
	for sx in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = head_r * 0.16
		tm.height = head_r * 0.7
		t.mesh = tm
		t.position = Vector3(sx * head_r * 0.5, head_y - head_r * 0.35, head_r * 0.72)
		t.material_override = tusk
		body.add_child(t)
	# hunched shoulder humps + a heavy upper back
	for sx in [-1.0, 1.0]:
		var hump := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = head_r
		hm.height = head_r * 2.0
		hump.mesh = hm
		hump.position = Vector3(sx * 0.62 * s, shoulder_y + 0.05 * s, -0.05 * s)
		hump.material_override = hide
		body.add_child(hump)
	var back := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = head_r * 1.3
	bm.height = head_r * 2.6
	back.mesh = bm
	back.position = Vector3(0, shoulder_y - 0.05 * s, -0.22 * s)
	back.scale = Vector3(1.2, 1.0, 0.9)
	back.material_override = hide
	body.add_child(back)


func _ogre_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.35
	return m


## A crude, heavy club resting against the right shoulder (knotted head + haft),
## scaled to the Giant. Parented to the figure root so it rides his sway.
func _make_club() -> Node3D:
	var s := HEIGHT / 2.0
	var club := Node3D.new()
	club.position = Vector3(0.42 * s, 1.5 * s, 0.1 * s)
	club.rotation = Vector3(0.5, 0, -0.35)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.13, 0.11)
	wood.roughness = 0.9
	var haft := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.07 * s
	hm.bottom_radius = 0.09 * s
	hm.height = 1.5 * s
	haft.mesh = hm
	haft.material_override = wood
	club.add_child(haft)
	var head := MeshInstance3D.new()
	var hd := SphereMesh.new()
	hd.radius = 0.28 * s
	hd.height = 0.56 * s
	head.mesh = hd
	head.position = Vector3(0, 0.8 * s, 0)
	head.material_override = wood
	club.add_child(head)
	return club


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var target: Vector3
	var speed := PATROL_SPEED
	var stalking := false
	if _player != null and is_instance_valid(_player) \
			and not GameState.has_flag("escaped_castle"):
		var pd := global_position.distance_to(_player.global_position)
		if pd <= SIGHT:
			target = _player.global_position
			speed = STALK_SPEED
			stalking = true
	if not stalking:
		target = _patrol_b if _to_b else _patrol_a
		if global_position.distance_to(target) < 0.8:
			_to_b = not _to_b

	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	# Turn the huge body to face where he moves / the pilgrim he stalks.
	if is_instance_valid(_fig) and dist > 0.05:
		var yaw := atan2(to.x, to.z)
		_fig.rotation.y = lerp_angle(_fig.rotation.y, yaw, clampf(delta * 4.0, 0.0, 1.0))
	# While slamming his club down he plants his feet (the weight reads).
	_slam_cd -= delta
	if _slamming:
		velocity.x = 0.0
		velocity.z = 0.0
	elif dist > (2.6 if stalking else 0.4):
		# He never crowds right up against the pilgrim (no contact attack); he looms.
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	# Looming close, he rears the great club and brings it crashing down — felt as
	# a screen-shake and a beat of hit-stop (Juice), pressing despair on the soul.
	if stalking and not _slamming and _slam_cd <= 0.0 and dist <= 6.5 \
			and not DialogueManager.is_active():
		_slam()
	# Keep him inside the bailey so he never wanders off the floor.
	global_position.x = clampf(global_position.x, _origin.x - 9.0, _origin.x + 9.0)
	global_position.z = clampf(global_position.z, _origin.z - 14.0, _origin.z + 7.0)
	move_and_slide()

	# Occasional low muttered accusation while he looms over you (not in dialogue).
	if stalking and not DialogueManager.is_active():
		_mutter += delta
		if _mutter >= 9.0:
			_mutter = 0.0
			EventBus.toast("绝望巨人低声逼问：「你永远出不去了。」(Giant Despair looms: 'You will never leave.')")


## Rear the club overhead and bring it crashing down; the impact fires the Juice.
func _slam() -> void:
	if _slamming or not is_instance_valid(_club):
		return
	_slamming = true
	_slam_cd = 8.5 if GameState.is_child_mode() else 5.5
	var rest := _club.rotation
	var raised := Vector3(-1.5, rest.y, rest.z - 0.25)
	var down := Vector3(1.0, rest.y, rest.z + 0.15)
	var tw := create_tween()
	tw.tween_property(_club, "rotation", raised, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_club, "rotation", down, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_slam_impact)
	tw.tween_property(_club, "rotation", rest, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _slamming = false)


func _slam_impact() -> void:
	if GameState.has_flag("escaped_castle"):
		return
	Juice.shake(0.6)
	Juice.hitstop(0.07)
	Juice.flash(Color(0.05, 0.06, 0.12, 0.3), 0.32)
	SpiritualStateManager.modify_state("despair", 5)
	var fwd := Vector3(0, 0, 1)
	if is_instance_valid(_fig):
		fwd = Vector3(sin(_fig.rotation.y), 0, cos(_fig.rotation.y))
	_spawn_dust(global_position + fwd * 1.9)
	if randf() < 0.4:
		EventBus.toast("巨棒砸在石地上，整座牢狱为之一震。(The club crashes down; the whole prison shudders.)")


## A short brown dust burst kicked up where the club strikes the floor.
func _spawn_dust(pos: Vector3) -> void:
	var host := get_parent()
	if host == null:
		host = self
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 26
	p.lifetime = 0.8
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -5.0, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var dm := SphereMesh.new()
	dm.radius = 0.16
	dm.height = 0.32
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.32, 0.29, 0.26, 0.7)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.mesh = dm
	host.add_child(p)
	p.global_position = Vector3(pos.x, 0.1, pos.z)
	var tree := get_tree()
	if tree != null:
		tree.create_timer(1.3).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())

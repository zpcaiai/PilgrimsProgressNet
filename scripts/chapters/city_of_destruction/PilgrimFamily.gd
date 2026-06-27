extends Node3D
class_name PilgrimFamily
## The pilgrim's wife (the SAME height as him, 2.0 m) and their two children, left
## behind in the City of Destruction. The wife reaches out, pleading; the children
## tug at her skirt — a clear "don't go" tableau. Built from the same in-engine
## HumanoidFigure cast as the rest of the game (its idle animator is removed so the
## arms can hold these poses). Spawned by ImportedSceneBinder from the NPC_Wife
## marker, so it uses the original scene + dialogue (wife_concern).

var _wife_body: Node3D = null
var _wife_arm_l: Node3D = null
var _wife_arm_r: Node3D = null
var _wife_base_y: float = 0.0
var _kids: Array = []
var _t: float = 0.0


func _ready() -> void:
	process_priority = 100  # pose arms after anything else this frame
	_build()


func _build() -> void:
	# --- wife: built to the pilgrim's exact height (2.0 m), maroon dress ---
	var wife := HumanoidFigure.make("Wife", 2.0, null, true, Color(0.49, 0.23, 0.27))
	add_child(wife)
	_free_animator(wife)
	_wife_body = wife.get_node_or_null("Body")
	if _wife_body != null:
		_wife_base_y = _wife_body.position.y
	_wife_arm_l = wife.get_node_or_null("Body/ArmL")
	_wife_arm_r = wife.get_node_or_null("Body/ArmR")

	# solid body (the pilgrim bumps her) + her plea, on interact
	_add_solid()
	_add_talk()

	# --- two children at her sides, leaning in and tugging her skirt ---
	_add_kid(Vector3(-0.7, 0, 0.3), 1.2, Color(0.42, 0.48, 0.29), -0.12, "ArmR", 1.0)
	_add_kid(Vector3(0.68, 0, 0.34), 1.32, Color(0.25, 0.42, 0.52), 0.12, "ArmL", -1.0)

	var label := Label3D.new()
	label.text = "妻子与孩子 / Your Family"
	label.position = Vector3(0, 2.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.009
	label.outline_size = 6
	add_child(label)


func _add_kid(pos: Vector3, height: float, tint: Color, lean: float, arm_name: String, sgn: float) -> void:
	var kid := HumanoidFigure.make("Child", height, null, true, tint)
	add_child(kid)
	kid.position = pos
	kid.rotation.z = lean  # lean toward the mother
	_free_animator(kid)
	var body := kid.get_node_or_null("Body")
	var arm := kid.get_node_or_null("Body/" + arm_name)
	var base_y := 0.0
	if body != null:
		base_y = body.position.y
	_kids.append({"body": body, "base_y": base_y, "arm": arm, "sign": sgn})


## Remove the figure's idle walk/sway animator so it no longer resets the arms
## each frame — letting us hold the pleading / tugging poses. (Meshes still cast
## the scene's real shadows.)
func _free_animator(fig: Node3D) -> void:
	for c in fig.get_children():
		if c is HumanoidAnimator:
			c.queue_free()


func _add_solid() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	sb.add_child(cs)
	add_child(sb)


func _add_talk() -> void:
	var talk := Interactable.new()
	talk.prompt = "听妻子的恳求 (Hear your family)"
	talk.one_shot = false
	talk.interact_callback = func(p):
		if is_instance_valid(p) and p.has_method("glance_toward"):
			p.call("glance_toward", global_position)
		if not DialogueManager.is_active():
			DialogueManager.start_dialogue("wife_concern")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	col.shape = sph
	col.position = Vector3(0, 0.9, 0)
	talk.add_child(col)
	add_child(talk)


func _process(delta: float) -> void:
	_t += delta
	# wife: a yearning forward tilt, a gentle breath, the right hand raised and
	# beckoning him back, the left arm open in appeal.
	if is_instance_valid(_wife_body):
		_wife_body.position.y = _wife_base_y + sin(_t * 1.5) * 0.02
		_wife_body.rotation.x = 0.12
	if is_instance_valid(_wife_arm_r):
		_wife_arm_r.rotation = Vector3(-1.2 + sin(_t * 2.0) * 0.13, 0.0, -0.18)
	if is_instance_valid(_wife_arm_l):
		_wife_arm_l.rotation = Vector3(-0.6 + sin(_t * 2.0 + 0.6) * 0.1, 0.0, 0.2)
	# children: the inner arm reaches up and inward, tugging the skirt (a small pull
	# rhythm); a soft bob.
	for k in _kids:
		var arm = k["arm"]
		if is_instance_valid(arm):
			arm.rotation = Vector3(-0.45, 0.0, float(k["sign"]) * (1.0 + sin(_t * 3.0) * 0.14))
		var body = k["body"]
		if is_instance_valid(body):
			body.position.y = float(k["base_y"]) + sin(_t * 1.7) * 0.015

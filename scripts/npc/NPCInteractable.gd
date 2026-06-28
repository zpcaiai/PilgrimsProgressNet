extends Interactable
class_name NPCInteractable
## An NPC placed from an NPC_* marker in the imported GLB. Builds its own visual
## (painted billboard when the figure art exists, else a greybox capsule + head)
## and a floating name, and starts its dialogue on interaction. Mirrors the look
## of ChapterBase.make_npc so GLB-driven chapters match the procedural ones.

var npc_name: String = "Stranger"
var dialogue_id: String = ""
var tint: Color = Color(0.7, 0.7, 0.75)


func setup(p_name: String, p_dialogue: String = "",
		p_tint: Color = Color(0.7, 0.7, 0.75)) -> void:
	npc_name = p_name
	dialogue_id = p_dialogue
	tint = p_tint
	var label_name := LocaleManager.npc_label(p_name)
	prompt = "交谈：" + label_name

	# A real in-engine 3D body, tinted by the character's palette (falling back to
	# `tint` for un-tabled folk). Standing NPCs idle in place (no mover).
	add_child(HumanoidFigure.make(p_name, 2.0, null, true, tint))

	var label := Label3D.new()
	label.text = label_name
	label.position = Vector3(0, 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.009
	label.outline_size = 6
	add_child(label)

	var col := CollisionShape3D.new()
	var cshape := CapsuleShape3D.new()
	cshape.radius = 0.6
	cshape.height = 1.8
	col.shape = cshape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	# A solid body (layer 1) so the pilgrim bumps into the NPC instead of passing
	# through it. Slimmer than the interaction radius so talking still works.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var bcol := CollisionShape3D.new()
	var bcap := CapsuleShape3D.new()
	bcap.radius = 0.4
	bcap.height = 1.6
	bcol.shape = bcap
	bcol.position = Vector3(0, 0.9, 0)
	body.add_child(bcol)
	add_child(body)

	interact_callback = func(_p):
		# Face-on-talk: the pilgrim turns toward this NPC and the NPC gives a nod.
		if _p != null and is_instance_valid(_p) and _p.has_method("glance_toward"):
			_p.call("glance_toward", global_position)
		var anim := HumanoidAnimator.find_in(self)
		if anim != null:
			anim.nudge(0.07)
		if dialogue_id != "" and not DialogueManager.is_active():
			DialogueManager.start_dialogue(dialogue_id)


## (The greybox capsule fallback is retired — every NPC is now a 3D body.)

extends RefCounted
class_name ImportedSceneBinder
## Walks an imported low-poly GLB and wires gameplay onto its nodes by NAME PREFIX
## (see docs/SCENE_NAMING_CONVENTIONS.md). Reuses the project's existing gameplay
## scripts (MudZone, PromiseStone, FalseGround, ArrowEmitter, PlayerCombat,
## BossController, CombatHUD) plus the lightweight trigger/zone scripts. Static.
##
## bind_scene(chapter, glb_path) instances the GLB under `chapter`, returns the
## player spawn position, or INVALID if the GLB could not be loaded (so the
## chapter can fall back to its procedural build).

const INVALID := Vector3(0, -99999, 0)

# Completion flags that must be set by an in-chapter event/boss (not the exit).
const EVENT_SET_FLAGS := ["burden_fallen", "defeated_apollyon"]

const PROMISE_LINES := {
	"hope": {"line": "Carved on the stone: 'Mist can hide the road, but it cannot erase it.'",
		"effects": {"hope": 8, "despair": -12}, "flag": "used_promise_hope"},
	"faith": {"line": "Carved on the stone: 'You do not stand because the mud is weak, but because mercy is strong.'",
		"effects": {"faith": 8, "fear": -6, "despair": -8}, "flag": "used_promise_faith"},
	"perseverance": {"line": "Carved on the stone: 'One true step is still obedience. Take it.'",
		"effects": {"perseverance": 8, "despair": -10}, "flag": "used_promise_perseverance"},
}

const NPC_DIALOGUE := {
	"NPC_Evangelist": "evangelist_first_call",
	"NPC_Wife": "wife_concern",
	"NPC_Children": "wife_concern",
	"NPC_Obstinate": "obstinate_confrontation",
	"NPC_Pliable": "pliable_joins",
	"NPC_Help": "help_rescue",
	"NPC_Goodwill": "wicket_gate_knock",
	"NPC_Interpreter": "interpreter_welcome",
	"NPC_Hopeful": "hopeful_joins",
	"NPC_Merchant_Applause": "merchant_applause",
	"NPC_GiantDespair": "giant_despair_accusation",
	"NPC_Shepherd_Knowledge": "shepherds_welcome",
	"NPC_Shepherd_Experience": "shepherds_counsel",
	"NPC_Shepherd_Watchful": "shepherd_warning",
	"NPC_Shepherd_Sincere": "shepherds_counsel",
	"NPC_ShiningOne_01": "shining_ones_welcome",
	"NPC_ShiningOne_02": "shining_ones_welcome",
	"NPC_Gatekeeper": "final_gate_entry",
	# Palace Beautiful — the porter and the four damsels (previously unmapped, so
	# their [E] Talk prompt fired nothing).
	"NPC_Watchman": "palace_porter",
	"NPC_Discretion": "palace_discretion",
	"NPC_Prudence": "palace_prudence",
	"NPC_Piety": "palace_piety",
	"NPC_Charity": "palace_charity",
	# Other scene NPCs that were never mapped.
	"NPC_TrialJudge": "vanity_trial",
	"NPC_Merchant_Comfort": "merchant_applause",
	"NPC_Merchant_Influence": "merchant_applause",
	"NPC_Faithful": "faithful_fellowship",
	"NPC_Timorous": "timorous_mistrust",
	"NPC_Mistrust": "timorous_mistrust",
	"NPC_Diffidence": "giant_despair_accusation",
	"NPC_Ignorance_Optional": "ignorance_optional",
}

# Per-chapter overrides for NPCs that appear in more than one chapter and speak
# different lines each time (e.g. Obstinate/Pliable: their pursuit in the City
# vs. their parting on the Wilderness Road). Looked up before NPC_DIALOGUE.
const NPC_DIALOGUE_BY_CHAPTER := {
	"wilderness_road": {
		"NPC_Obstinate": "obstinate_road",
		"NPC_Pliable": "pliable_doubting",
	},
}

const TRIGGER_DIALOGUE := {
	"TRIGGER_ProclamationRead": "city_proclamation",
	"TRIGGER_FeastWelcome": "celestial_feast_welcome",
	"TRIGGER_PliableLeaves": "pliable_leaves",
	"TRIGGER_ObstinateReturns": "obstinate_road",
	"TRIGGER_PliableRoadDialogue": "pliable_doubting",
	"TRIGGER_CityVoices": "wilderness_city_voices",
	"TRIGGER_FixEyesOnLight": "wilderness_resolve",
	"TRIGGER_HelpAppears": "help_rescue",
	"TRIGGER_GateKnock": "wicket_gate_knock",
	"TRIGGER_ArborRest": "rest_arbor",
	"TRIGGER_ApollyonIntro": "apollyon_encounter",
	"TRIGGER_PalaceDoorExamination": "palace_welcome",
	"TRIGGER_FaithfulTrial": "vanity_trial",
	"TRIGGER_HopefulJoins": "hopeful_joins",
	"TRIGGER_PathChoiceFork": "hill_path_choice",
	"TRIGGER_CageRoomStart": "caged_man_vision",
	"TRIGGER_ReceiveShepherdMap": "shepherd_warning",
	"TRIGGER_TestimonyConversation": "testimony_recall",
	"TRIGGER_EnterRiver": "river_entry",
	"TRIGGER_RiverMemoryRecall": "river_memory_recall",
	"TRIGGER_MidRiverFear": "river_memory_recall",
}

const VIEWPOINT_FLAG := {
	"PROP_Viewpoint_CelestialCity": "saw_celestial_city_from_mountains",
	"PROP_Viewpoint_ErrorCliff": "received_shepherd_warning",
	"PROP_Viewpoint_ShortcutGrave": "received_shepherd_warning",
}


static func bind_scene(chapter: Node3D, glb_path: String) -> Vector3:
	if glb_path == "" or not ResourceLoader.exists(glb_path):
		return INVALID
	var packed: PackedScene = load(glb_path)
	if packed == null:
		return INVALID
	var root: Node = packed.instantiate()
	if root == null:
		return INVALID
	chapter.add_child(root)

	var nodes: Array = []
	_collect(root, nodes)

	var spawn := Vector3(0, 1, 0)
	var burden_node: Node3D = null
	var path_points: Dictionary = {}
	var cross_trigger = null

	for n in nodes:
		var nm := String(n.name)
		if nm == "SPAWN_Player_Start":
			spawn = n.global_position
		elif nm.begins_with("ENV_"):
			# The raised river surface is a wade-through water sheet, not a floor.
			if "WaterSurface" not in nm:
				_add_env_collision(n)
		elif nm == "ENEMY_ApollyonBoss":
			_setup_boss(chapter, n.global_position)
			n.visible = false
		elif nm == "ENEMY_RiverMonster":
			_setup_river_monster(chapter, n.global_position)
			n.visible = false
		elif nm.begins_with("NPC_"):
			_bind_npc(chapter, n)
		elif nm.begins_with("TRIGGER_"):
			var t = _bind_trigger(chapter, n, nm)
			if t != null:
				cross_trigger = t
		elif nm.begins_with("COL_"):
			_bind_hazard(chapter, n, nm)
		elif nm.begins_with("PROP_"):
			var b = _bind_prop(chapter, n, nm)
			if b != null:
				burden_node = b
		elif nm.begins_with("LIGHT_"):
			_bind_light(chapter, n, nm)
		elif nm.begins_with("VFX_ArrowEmitter"):
			_make_arrow_emitter(chapter, n.global_position)
		elif nm.begins_with("PATH_BurdenRoll"):
			path_points[nm] = n.global_position
		elif nm.begins_with("CAM_"):
			n.add_to_group("cinematic_camera")

	# Solidify structures and props so the pilgrim bumps them instead of walking
	# through (ENV_ already got trimesh collision above; here we cover the composite
	# visuals and standalone props, skipping decor / doors / pickups).
	for n in nodes:
		var snm := String(n.name)
		if n is MeshInstance3D and (snm.begins_with("VIS_") or snm.begins_with("PROP_")):
			if _is_solid(snm):
				_add_box_collision(n as MeshInstance3D)

	# Wire the Cross grace sequence if both the trigger and burden exist.
	if cross_trigger != null and burden_node != null:
		var ctrl := CrossEventController.new()
		chapter.add_child(ctrl)
		var ordered: Array = []
		for key in ["PATH_BurdenRoll_Start", "PATH_BurdenRoll_Mid", "PATH_BurdenRoll_End"]:
			if path_points.has(key):
				ordered.append(path_points[key])
		ctrl.configure(burden_node, ordered)
		cross_trigger.configure(ctrl)

	return spawn


# ---------------------------------------------------------------------------
static func _collect(node: Node, out: Array) -> void:
	out.append(node)
	for c in node.get_children():
		_collect(c, out)


static func _box_size(node: Node) -> Vector3:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh.get_aabb().size
	return Vector3(3, 3, 3)


static func _add_env_collision(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		(node as MeshInstance3D).create_trimesh_collision()


## Whether a prop/structure mesh should block the player. Skips backdrops, decor,
## VFX visuals, doors the player walks through, and pickups/interactables.
static func _is_solid(nm: String) -> bool:
	for skip in ["Backdrop", "Silhouette", "Distant", "Banner", "Reeds",
			"DreamFlower", "SoftGrass", "Sword", "Shield", "RollingBurden",
			"PromiseStone", "ValleyView", "StormCloud", "Glow", "Light", "Fire",
			"Pollen", "Mist", "AwakeStone", "FaintPathMarker", "Book",
			"ScrollMarker", "SealMarker", "NewGarment", "GateDoor", "CellDoor",
			"Grass", "Tuft", "Foliage", "Flower", "Bush", "Crow", "Smoke",
			"Ember", "Sheep", "Crowd", "Hedge", "Ridge", "Cairn",
			"Merlon", "Crown", "WaterSurface",
			# Living-worlds pass: ambient life is always walk-through.
			"Fauna", "Critter", "Household", "Dove", "Butterfly", "Firefly"]:
		if skip in nm:
			return false
	return true


## Add a box StaticBody (layer 1) sized to the mesh, as a child of the mesh so it
## inherits the world transform. Cheap, greybox-appropriate solid collision.
static func _add_box_collision(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var aabb := mi.mesh.get_aabb()
	if aabb.size.x <= 0.0 or aabb.size.y <= 0.0 or aabb.size.z <= 0.0:
		return
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	cs.shape = box
	cs.position = aabb.position + aabb.size * 0.5
	sb.add_child(cs)
	mi.add_child(sb)


static func _make_interactable(chapter: Node3D, pos: Vector3, prompt: String,
		cb: Callable, one_shot: bool = true, radius: float = 1.4) -> Interactable:
	var area := Interactable.new()
	area.prompt = prompt
	area.one_shot = one_shot
	area.interact_callback = cb
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	col.shape = sph
	col.position = Vector3(0, 0.8, 0)
	area.add_child(col)
	chapter.add_child(area)
	area.global_position = pos
	return area


static func _story(chapter: Node3D, node: Node, effects: Dictionary,
		flags: Dictionary, special: Dictionary, toast: String) -> void:
	var st := StoryEventTrigger.new()
	chapter.add_child(st)
	st.setup(_box_size(node), effects, flags, special, toast)
	st.global_position = node.global_position
	if node is Node3D:
		(node as Node3D).visible = false


# ---------------------------------------------------------------------------
static func _bind_npc(chapter: Node3D, node: Node) -> void:
	var nm := String(node.name)
	# Giant Despair is no generic NPC capsule: spawn the real towering Giant who
	# prowls the castle hall, looms over the pilgrim, and can be faced (his
	# accusation). He presses despair as a presence; escape is by the Promise key.
	if nm == "NPC_GiantDespair":
		var giant := GiantDespair.new()
		chapter.add_child(giant)
		giant.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return
	# The pilgrim's family he leaves behind: his wife (same height as him) reaching
	# out, with two children tugging her skirt. Replaces the single folded figure.
	if nm == "NPC_Wife":
		var fam := PilgrimFamily.new()
		chapter.add_child(fam)
		fam.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return
	if nm == "NPC_Hopeful" and GameState.has_companion("hopeful"):
		if node is Node3D:
			(node as Node3D).visible = false
		return
	# The family is shown as one figure (your_family.webp); the Children marker is
	# folded into the Wife's family figure so there are not two generic capsules.
	if nm == "NPC_Children":
		if node is Node3D:
			(node as Node3D).visible = false
		return
	# Apollyon is represented by the boss (ENEMY_ApollyonBoss at the same spot);
	# don't also spawn a talkable NPC figure overlapping him.
	if nm == "NPC_Apollyon":
		if node is Node3D:
			(node as Node3D).visible = false
		return
	var overrides: Dictionary = NPC_DIALOGUE_BY_CHAPTER.get(
		String(ChapterManager.current_chapter_id), {})
	var dlg := String(overrides.get(nm, NPC_DIALOGUE.get(nm, "")))
	var disp := nm.substr(4).replace("_", " ")
	if nm == "NPC_Wife":
		disp = "Your Family"
	var npc := NPCInteractable.new()
	chapter.add_child(npc)
	npc.setup(disp, dlg)
	npc.global_position = node.global_position
	if node is Node3D:
		(node as Node3D).visible = false


static func _bind_trigger(chapter: Node3D, node: Node, nm: String):
	var size := _box_size(node)
	if nm.begins_with("TRIGGER_Exit_") or nm == "TRIGGER_DemoEnd":
		_bind_exit(chapter, node)
		return null
	if nm == "TRIGGER_EnterCelestialCity":
		# The gate WELCOMES you in -- it no longer cuts to credits. The finale is
		# now reached by walking the City: the host, the feast, and the throne.
		_story(chapter, node, {"hope": 10, "faith": 10, "fear": -20, "despair": -20},
			{"entered_city": true}, {},
			"You pass through the gate. Within: light, white robes, the sound of a great multitude, and a feast spread down the length of the City. The welcome has only begun.")
		return null
	if nm == "TRIGGER_ThroneWorship":
		# The true finale, before the throne -- only after the City is walked.
		_story(chapter, node, {"faith": 20, "hope": 20},
			{"entered_celestial_city": true, "journey_completed": true},
			{"show_journey_review": true, "show_credits": true},
			"You come at last before the throne. The crowned Lamb who was slain is seated in glory, and the host falls down in worship. Not by your strength, but by grace, you are home.")
		return null
	if nm == "TRIGGER_EndCredits" or nm == "TRIGGER_JourneyReview":
		_story(chapter, node, {}, {"journey_review_requested": true}, {},
			"The journey is remembered.")
		return null
	if nm == "TRIGGER_ReadBook":
		_story(chapter, node, {"despair": 10, "fear": 5, "humility": 5},
			{"read_book": true, "received_burden": true}, {},
			"You read, and a weight you cannot remove settles on your back.")
		return null
	if nm == "TRIGGER_CrossEvent":
		var ct := CrossEventTrigger.new()
		chapter.add_child(ct)
		ct.setup(size)
		ct.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return ct
	if nm == "TRIGGER_ReceiveArmor":
		var ag := ArmorGrantTrigger.new()
		chapter.add_child(ag)
		ag.setup(size)
		ag.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return null
	if nm == "TRIGGER_PrayerPrompt":
		var pp := PrayerPromptTrigger.new()
		chapter.add_child(pp)
		pp.setup(size)
		pp.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return null
	if nm == "TRIGGER_Capture":
		_story(chapter, node, {"despair": 10, "fear": 3},
			{"captured_by_giant_despair": true, "entered_doubting_castle": true}, {},
			"Giant Despair seizes you. You wake in a cold cell.")
		return null
	if nm == "TRIGGER_FaithfulLost":
		_story(chapter, node, {"faith": 10, "perseverance": 8, "fear": 8},
			{"faithful_witnessed": true, "faithful_lost": true}, {},
			"Faithful is taken, faithful to the end. His witness burns in you.")
		return null
	if nm == "TRIGGER_EnterVanityFair":
		_story(chapter, node, {}, {"entered_vanity_fair": true}, {}, "")
		return null
	if nm == "TRIGGER_EnterEnchantedGround":
		_story(chapter, node, {}, {"entered_enchanted_ground": true}, {}, "")
		return null
	if nm == "TRIGGER_ByPathChoice":
		_story(chapter, node, {"deception": 5, "watchfulness": -3},
			{"entered_doubting_castle": true}, {},
			"The soft meadow looks kinder than the road.")
		return null
	if nm == "TRIGGER_HopefulWake":
		_story(chapter, node, {"watchfulness": 8, "hope": 5, "weariness": -3},
			{"resisted_sleep": true}, {}, "Hopeful's voice pulls you back from sleep.")
		return null
	if nm == "TRIGGER_BossStart" or nm == "TRIGGER_BossVictory":
		if node is Node3D:
			(node as Node3D).visible = false
		return null
	if TRIGGER_DIALOGUE.has(nm):
		var dt := DialogueTrigger.new()
		chapter.add_child(dt)
		dt.setup(size, String(TRIGGER_DIALOGUE[nm]))
		dt.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return null
	if node is Node3D:
		(node as Node3D).visible = false
	return null


static func _bind_exit(chapter: Node3D, node: Node) -> void:
	var data: Dictionary = ChapterManager.get_current_chapter_data()
	var set_flags: Dictionary = {}
	var require := ""
	for cond in data.get("completion_conditions", []):
		var key := String(cond.get("key", ""))
		if EVENT_SET_FLAGS.has(key):
			require = key
		else:
			set_flags[key] = cond.get("value", true)
	if String(ChapterManager.current_chapter_id) == "city_of_destruction":
		require = "talked_to_evangelist"
	var ex := ChapterExitTrigger.new()
	chapter.add_child(ex)
	ex.setup(_box_size(node), set_flags, require,
		"先与传道者交谈，领受当行的路。 (Speak with Evangelist first — he sets you on the way.)")
	ex.global_position = node.global_position
	_spawn_exit_portal(chapter, node.global_position)
	if node is Node3D:
		(node as Node3D).visible = false


## A visible "portal": a soft glowing light-beam + ground ring + lamp marking the
## chapter exit, so the way out is unmistakable.
static func _spawn_exit_portal(chapter: Node3D, pos: Vector3) -> void:
	var portal := ExitPortal.new()
	portal.position = pos
	# Deferred: binding runs during the chapter's setup; a direct add_child can
	# fail with "parent busy setting up children".
	chapter.add_child.call_deferred(portal)


static func _bind_hazard(chapter: Node3D, node: Node, nm: String) -> void:
	var size := _box_size(node)
	if "MemoryPrompt" in nm:
		var dt := DialogueTrigger.new()
		chapter.add_child(dt)
		dt.setup(size, "river_memory_recall")
		dt.global_position = node.global_position
		if node is Node3D:
			(node as Node3D).visible = false
		return
	var z: Area3D = null
	if "RiverWater" in nm:
		# The wet stretch: drives the swim posture + the fear/faith wade slowdown.
		z = RiverWaterZone.new()
		chapter.add_child(z)
		(z as RiverWaterZone).setup(size)
	elif "MudZone_Deep" in nm:
		z = MudZone.new()
		chapter.add_child(z)
		(z as MudZone).setup(size, true)
	elif "MudZone" in nm:
		z = MudZone.new()
		chapter.add_child(z)
		(z as MudZone).setup(size, false)
	elif "FalseGround" in nm:
		z = FalseGround.new()
		chapter.add_child(z)
		(z as FalseGround).setup(size)
	elif "ArrowPressureZone" in nm:
		z = ArrowPressureZone.new()
		chapter.add_child(z)
		(z as ArrowPressureZone).setup(size)
	elif "Shame" in nm:
		z = ShameFieldZone.new()
		chapter.add_child(z)
		(z as ShameFieldZone).setup(size)
	elif "Despair" in nm:
		z = DespairFlameZone.new()
		chapter.add_child(z)
		(z as DespairFlameZone).setup(size)
	elif "FalseVoice" in nm:
		z = FalseVoiceZone.new()
		chapter.add_child(z)
		(z as FalseVoiceZone).setup(size)
	elif "Fear" in nm or "River" in nm:
		z = FearZone.new()
		chapter.add_child(z)
		(z as FearZone).setup(size)
	elif "Sleep" in nm:
		z = HazardZone.new()
		chapter.add_child(z)
		(z as HazardZone).setup(size, {"watchfulness": -2, "deception": 1}, 3.0,
			"Sleep tugs at your eyes here. Keep moving, keep talking.", "")
	elif "Vanity" in nm or "Applause" in nm or "Comfort" in nm or "Influence" in nm or "Crowd" in nm:
		z = HazardZone.new()
		chapter.add_child(z)
		(z as HazardZone).setup(size, {"pride": 1, "deception": 1}, 3.0,
			"The fair flatters and presses. Keep to the road.", "")
	else:
		z = HazardZone.new()
		chapter.add_child(z)
		(z as HazardZone).setup(size, {"fear": 1}, 3.0, "", "")
	if z != null:
		z.global_position = node.global_position
	if node is Node3D:
		(node as Node3D).visible = false


static func _bind_prop(chapter: Node3D, node: Node, nm: String):
	var pos := (node as Node3D).global_position if node is Node3D else Vector3.ZERO
	if nm == "PROP_Chapel":
		# Worship at the chapel: a one-time blessing strengthening the whole soul.
		var worship_cb := func(_p):
			SpiritualStateManager.apply_effects({
				"faith": 2, "hope": 2, "humility": 2,
				"discernment": 2, "watchfulness": 2, "perseverance": 2})
			GameState.set_flag("worshipped_at_chapel", true)
			EventBus.toast("你在小教堂里跪下礼拜，灵命得了坚固。(You worship in the chapel; your soul is strengthened.)")
		_make_interactable(chapter, pos, "在教堂礼拜 (Worship)", worship_cb, true, 2.4)
		return null
	if nm == "PROP_Book":
		_make_interactable(chapter, pos, "读那本书 (Read)",
			func(_p): SpiritualStateManager.trigger_spiritual_event("receive_burden"))
	elif nm == "PROP_WaysideStone":
		var rest_cb := func(_p):
			if not DialogueManager.is_active():
				DialogueManager.start_dialogue("wilderness_burden")
		_make_interactable(chapter, pos, "在重担下停歇 (Rest)", rest_cb, false, 1.8)
	elif nm.begins_with("PROP_PromiseStone_"):
		var kind := "hope"
		if "Faith" in nm:
			kind = "faith"
		elif "Perseverance" in nm:
			kind = "perseverance"
		var d: Dictionary = PROMISE_LINES[kind]
		var ps := PromiseStone.new()
		chapter.add_child(ps)
		ps.setup(String(d["line"]), d["effects"], String(d["flag"]))
		ps.global_position = pos
		if node is Node3D:
			(node as Node3D).visible = false
	elif nm == "PROP_ArmorStand":
		var ai := ArmorInteractable.new()
		chapter.add_child(ai)
		ai.setup()
		ai.global_position = pos
	elif nm == "PROP_Sword" or nm == "PROP_Shield":
		var eq := EquipmentPickup.new()
		chapter.add_child(eq)
		eq.setup("sword" if nm == "PROP_Sword" else "shield")
		eq.global_position = pos
	elif nm == "PROP_PromiseKey":
		_make_interactable(chapter, pos, "记起应许 (Remember)",
			func(_p): SpiritualStateManager.trigger_spiritual_event("promise_key_escape"))
	elif nm == "PROP_ShepherdMap":
		_make_interactable(chapter, pos, "领受地图 (Receive map)",
			func(_p): SpiritualStateManager.trigger_spiritual_event("shepherd_map_received"))
	elif nm.begins_with("PROP_Viewpoint_"):
		var vf := String(VIEWPOINT_FLAG.get(nm, "met_shepherds"))
		_make_interactable(chapter, pos, "观看远方 (Look)",
			func(_p):
				GameState.set_flag("met_shepherds", true)
				GameState.set_flag(vf, true)
				SpiritualStateManager.apply_effects({"hope": 8, "watchfulness": 3})
				EventBus.toast("你久久观看，道路渐渐清晰。"))
	elif nm.begins_with("PROP_TestimonyMarker_"):
		_make_interactable(chapter, pos, "开口记念 (Remember aloud)",
			func(_p):
				GameState.set_flag("shared_testimony_with_hopeful", true)
				GameState.set_flag("resisted_sleep", true)
				SpiritualStateManager.apply_effects({"faith": 5, "hope": 5, "watchfulness": 5})
				EventBus.toast("你告诉盼望：一路是谁托住你。说出口，使你保持清醒。"))
	elif nm == "PROP_CelestialGate":
		_make_interactable(chapter, pos, "进入城门 (Enter)",
			func(_p): DialogueManager.start_dialogue("final_gate_entry"))
	elif nm == "PROP_RollingBurden":
		return node
	return null


static func _bind_light(chapter: Node3D, node: Node, nm: String) -> void:
	if "Main" in nm or "Dim" in nm:
		return  # ambient handled by the chapter art profile's directional rig
	var omni := OmniLight3D.new()
	var red := ("Red" in nm) or ("Boss" in nm)
	var warm := ("Warm" in nm) or ("Gold" in nm) or ("Glow" in nm) or ("Sun" in nm) \
		or ("Hearth" in nm) or ("Fire" in nm) or ("Sunrise" in nm) or ("Prayer" in nm)
	if red:
		omni.light_color = Color(1.0, 0.4, 0.25)
	elif warm:
		omni.light_color = Color(1.0, 0.9, 0.65)
	else:
		omni.light_color = Color(0.7, 0.78, 0.95)
	omni.light_energy = 2.6 if (warm or red) else 1.3
	omni.omni_range = 16.0
	chapter.add_child(omni)
	omni.global_position = node.global_position


static func _make_arrow_emitter(chapter: Node3D, pos: Vector3) -> void:
	var e := ArrowEmitter.new()
	chapter.add_child(e)
	e.global_position = pos
	e.add_to_group("arrow_emitter")
	e.active = false


static func _setup_boss(chapter: Node3D, pos: Vector3) -> void:
	var player = chapter.get("player")
	if player != null:
		var pc := PlayerCombat.new()
		player.add_child(pc)
		if SpiritualStateManager.has_promise_key:
			pc.promise_charge = 3
	chapter.add_child(CombatHUD.new())
	var enc := BossEncounter.new()
	chapter.add_child(enc)
	enc.setup("apollyon_encounter", pos)


## The River of Death creature: a symbolic, non-lethal leviathan that bars the
## crossing and presses fear, sinking away once faith leads.
static func _setup_river_monster(chapter: Node3D, pos: Vector3) -> void:
	var m := RiverMonster.new()
	chapter.add_child(m)
	m.global_position = pos

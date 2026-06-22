extends GlbChapter
class_name CityOfDestruction
## Chapter 1. The doomed city. Talk to Evangelist to learn the way, weather the
## family's plea and Obstinate's mockery, then leave through the eastern gate.


# Use the hand-built grounded scene (not the floating GLB greybox) for chapter 1,
# so the pilgrim starts on solid ground in front of his home.
func _prefer_procedural() -> bool:
	return true


func _build_procedural() -> void:
	setup_environment(
		Color(0.35, 0.12, 0.1),   # smoky red sky top
		Color(0.5, 0.25, 0.15),   # dim orange horizon
		0.55                       # low ambient: heavy, oppressive
	)
	# Large ground so the earth reads solid to the horizon (no floating slab).
	make_ground(Vector2(160, 180), Color(0.30, 0.26, 0.22))
	# Smoky distance haze so the far ground melts into the burning sky.
	var env := _find_or_make_env()
	if env != null:
		env.fog_enabled = true
		env.fog_density = 0.012
		env.fog_light_color = Color(0.5, 0.32, 0.24)
		env.fog_sky_affect = 0.3

	# The pilgrim's home — a real house right before him at the start.
	_build_family_house(Vector3(-5.5, 0, 3.5))

	# Neighbour houses hemming the road in (off the path).
	PropKit.cottage(self, Vector3(8, 0, 7), Vector3(5, 3.2, 5), Color(0.5, 0.43, 0.4), Color(0.30, 0.20, 0.15))
	PropKit.cottage(self, Vector3(10, 0, -3), Vector3(4.5, 3.0, 4.5), Color(0.46, 0.4, 0.37), Color(0.28, 0.19, 0.14))
	PropKit.cottage(self, Vector3(-11, 0, -6), Vector3(4.5, 3.2, 4.5), Color(0.48, 0.42, 0.38), Color(0.30, 0.20, 0.14))

	# Distant fire glow behind the city (the doom you are fleeing).
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 6, 28)
	glow.light_color = Color(1.0, 0.4, 0.2)
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	add_child(glow)

	# The light of the gate, far ahead (forward = -Z), with a real gate + lanterns.
	make_distant_light(Vector3(0, 5, -34))
	make_floating_label("Toward the Wicket Gate", Vector3(0, 3.5, -20), Color(1, 0.95, 0.7))
	PropKit.gate(self, Vector3(0, 0, -20), Color(0.45, 0.42, 0.38), true)
	PropKit.lantern_post(self, Vector3(-3, 0, -1))
	PropKit.lantern_post(self, Vector3(3, 0, -10))

	# NPCs
	make_npc("Evangelist", Vector3(0, 0, -4), Color(0.85, 0.8, 0.6), "evangelist_first_call")
	make_npc("Obstinate", Vector3(3, 0, -13), Color(0.45, 0.4, 0.35), "obstinate_confrontation")
	make_npc("Pliable", Vector3(-3, 0, -13), Color(0.6, 0.7, 0.5), "pliable_joins")

	spawn_player(Vector3(0, 1, 8))

	# Leave through the gate — gated by Evangelist's call AND the Scripture Gate.
	var _cb1 := func(_b): _try_leave_city()
	make_trigger(Vector3(0, 1.5, -21), Vector3(12, 4, 2), _cb1, false)
	# Visible exit portal at the gate (procedural chapters skip the binder that
	# normally spawns it, so add it here too). Deferred add: this runs during the
	# chapter's setup, and a direct add_child can fail with "parent busy".
	var portal := ExitPortal.new()
	portal.position = Vector3(0, 0, -21)
	add_child.call_deferred(portal)


## Leaving the City requires Evangelist's word, then a correct Scripture answer.
func _try_leave_city() -> void:
	if not GameState.has_flag("talked_to_evangelist"):
		EventBus.toast("先与传道者交谈，领受当行的路。 (Speak with Evangelist first — he sets you on the way.)")
		return
	if GameState.has_flag("scripture_city_of_destruction") or not ScriptureGate.has_question("city_of_destruction"):
		_city_leave()
		return
	var on_pass := func() -> void:
		GameState.set_flag("scripture_city_of_destruction", true)
		_city_leave()
	ScriptureGate.open(self, "city_of_destruction", on_pass)


func _city_leave() -> void:
	GameState.set_flag("left_city", true)
	QuestManager.update_quest_progress("leave_city")
	EventBus.toast("You leave the City of Destruction behind, carrying the burden into mercy's road.")
	_advance_after_delay()


## The family home: a realistic timber-framed cottage with warm-lit windows and
## the family (your_family.webp) standing in the glowing doorway, begging the
## pilgrim to stay. Built so the pilgrim opens the chapter standing before it.
func _build_family_house(pos: Vector3) -> void:
	var size := Vector3(7.0, 4.2, 6.0)
	_build_house_shell(pos, size)
	var fz := pos.z + size.z * 0.5   # front face (+Z, toward the spawn/camera)

	# Stone foundation skirt at the base — grounds the house, reads as real.
	make_block(Vector3(size.x + 0.3, 0.5, size.z + 0.3), Color(0.40, 0.38, 0.34), Vector3(pos.x, 0.25, pos.z))

	# Tudor timber framing on the front.
	var beam := Color(0.26, 0.18, 0.12)
	make_block(Vector3(0.18, size.y, 0.1), beam, Vector3(pos.x - 2.7, size.y * 0.5, fz + 0.02))
	make_block(Vector3(0.18, size.y, 0.1), beam, Vector3(pos.x + 2.7, size.y * 0.5, fz + 0.02))
	make_block(Vector3(size.x, 0.18, 0.1), beam, Vector3(pos.x, size.y - 0.12, fz + 0.02))
	make_block(Vector3(size.x, 0.18, 0.1), beam, Vector3(pos.x, size.y * 0.55, fz + 0.02))

	# Framed door with lintel and a stone step.
	make_block(Vector3(1.7, 2.7, 0.08), Color(0.22, 0.14, 0.08), Vector3(pos.x, 1.35, fz + 0.02))   # frame
	make_block(Vector3(1.3, 2.3, 0.16), Color(0.26, 0.17, 0.10), Vector3(pos.x, 1.15, fz + 0.06))   # door
	make_block(Vector3(1.9, 0.22, 0.3), beam, Vector3(pos.x, 2.72, fz + 0.12))                       # lintel
	make_block(Vector3(1.8, 0.22, 0.7), Color(0.42, 0.40, 0.36), Vector3(pos.x, 0.11, fz + 0.45))    # stone step

	# Warm-lit windows with mullions.
	_lit_window(Vector3(pos.x - 2.2, 2.05, fz + 0.04))
	_lit_window(Vector3(pos.x + 2.2, 2.05, fz + 0.04))

	# A lantern by the door.
	PropKit.lantern_post(self, Vector3(pos.x + 1.6, 0, fz + 0.7))

	# Warm interior light spilling from the doorway.
	var hearth := OmniLight3D.new()
	hearth.position = pos + Vector3(0, 1.6, 0.5)
	hearth.light_color = Color(1.0, 0.78, 0.48)
	hearth.light_energy = 2.8
	hearth.omni_range = 7.5
	add_child(hearth)

	# Chimney smoke (a lived-in home).
	PropKit.smoke(self, pos + Vector3(size.x * 0.3, size.y + 1.4, -size.z * 0.2), 0.7)

	# Drawing near home eases the heart once.
	var family_solace := func(_b: Node) -> void:
		SpiritualStateManager.apply_effects({"despair": -5, "weariness": -5})
		EventBus.toast("Home's familiar warmth steadies you — despair and weariness ease a little.")
	make_trigger(pos + Vector3(0, 1.0, 2.6), Vector3(8, 3, 7), family_solace)

	# The family in the lit doorway — a real in-engine 3D body, a touch taller so
	# they read clearly in the doorway. Standing (no mover), so they idle in place.
	var spr := HumanoidFigure.make("Your Family", 2.2, null, true, Color(0.6, 0.45, 0.55))
	spr.position.x = pos.x
	spr.position.z = fz + 0.8
	add_child(spr)

	# Interaction at the door: the family begs the pilgrim to stay.
	var area := Interactable.new()
	area.name = "YourFamily"
	area.position = Vector3(pos.x, 0, fz + 1.8)
	area.prompt = "Dear My Love 求你别走"
	area.interact_callback = func(_p): DialogueManager.start_dialogue("wife_concern")
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	col.position = Vector3(0, 0.9, 0)
	area.add_child(col)
	add_child(area)
	make_floating_label("Dear My Love", Vector3(pos.x, 3.6, fz + 0.9), Color(0.85, 0.7, 0.7))


## A small warm-lit window: dark frame + an emissive amber pane.
func _lit_window(p: Vector3) -> void:
	make_block(Vector3(1.2, 1.2, 0.1), Color(0.28, 0.20, 0.12), p)                              # frame
	make_block(Vector3(0.9, 0.9, 0.06), Color(1.0, 0.82, 0.5), p + Vector3(0, 0, 0.04), 1.2)    # warm glass
	make_block(Vector3(0.92, 0.08, 0.06), Color(0.26, 0.18, 0.10), p + Vector3(0, 0, 0.07))     # mullion (horizontal)
	make_block(Vector3(0.08, 0.92, 0.06), Color(0.26, 0.18, 0.10), p + Vector3(0, 0, 0.07))     # mullion (vertical)


## A textured house shell: brick walls (with a door gap), a terracotta-tile gable
## roof and a brick chimney. Replaces the flat cottage for the hero family home.
func _build_house_shell(pos: Vector3, size: Vector3) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var t := 0.3
	var br := Color(1, 1, 1)   # keep the brick preset colour (bright texture)
	make_block(Vector3(w, h, t), br, Vector3(pos.x, h * 0.5, pos.z - d * 0.5), 0.0, "brick")
	make_block(Vector3(t, h, d), br, Vector3(pos.x - w * 0.5, h * 0.5, pos.z), 0.0, "brick")
	make_block(Vector3(t, h, d), br, Vector3(pos.x + w * 0.5, h * 0.5, pos.z), 0.0, "brick")
	var door_w := w * 0.32
	var seg := (w - door_w) * 0.5
	make_block(Vector3(seg, h, t), br, Vector3(pos.x - (door_w + seg) * 0.5, h * 0.5, pos.z + d * 0.5), 0.0, "brick")
	make_block(Vector3(seg, h, t), br, Vector3(pos.x + (door_w + seg) * 0.5, h * 0.5, pos.z + d * 0.5), 0.0, "brick")
	make_block(Vector3(door_w, h * 0.30, t), br, Vector3(pos.x, h - h * 0.15, pos.z + d * 0.5), 0.0, "brick")
	# Terracotta-tile gable roof (textured prism, like the cottage roof).
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.6, h * 0.7, d + 0.6)
	roof.mesh = prism
	roof.material_override = MaterialKit.make("rooftile", Color(1, 1, 1), {"uv_scale": 1.1})
	roof.position = Vector3(pos.x, h + h * 0.35, pos.z)
	add_child(roof)
	# Brick chimney.
	make_block(Vector3(0.6, 1.4, 0.6), br, Vector3(pos.x + w * 0.28, h + h * 0.5, pos.z - d * 0.2), 0.0, "brick")

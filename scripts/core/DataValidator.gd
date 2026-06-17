extends RefCounted
class_name DataValidator
## Validates the JSON data pack. Call DataValidator.validate_all_data() to get a
## list of error strings (empty == everything is consistent). Mirrors
## tools/validation/validate_data.py so the same guarantees hold headless and
## in-engine. Static utility (not an autoload); uses DataLoader for reads.

const IMPORTED_SCENE_DIR := "res://assets/imported_scenes/"

const SUPPORTED_SPECIALS := [
	"trigger_event", "start_boss", "add_companion", "remove_companion",
	"grant_armor", "grant_sword", "grant_shield", "grant_promise_key",
	"grant_shepherd_map", "grant_final_seal", "activate_prayer_light",
	"show_journey_review", "show_credits",
	"remove_burden", "grant_scroll", "grant_seal", "grant_new_garment", "cross_grace",
]


static func validate_all_data() -> Array:
	var errors: Array = []
	var chapters := DataLoader.load_category("chapters")
	var quests := DataLoader.load_category("quests")
	var routes := DataLoader.load_category("route")
	var dialogues := DataLoader.load_category("dialogues")
	var events := DataLoader.load_category("spiritual_events")
	var interactables := DataLoader.load_category("interactables")
	var hazards := DataLoader.load_category("hazards")
	var enemies := DataLoader.load_category("enemies")
	var items := DataLoader.load_category("items")
	var companions := DataLoader.load_category("companions")

	errors.append_array(_dup_ids("chapter", chapters))
	errors.append_array(_dup_ids("quest", quests))
	errors.append_array(_dup_ids("dialogue", dialogues))

	# --- Chapters ---
	for cid in chapters:
		var c: Dictionary = chapters[cid]
		if String(c.get("title", "")) == "":
			errors.append("Chapter %s missing title." % cid)
		var scene_path := String(c.get("scene_path", ""))
		if scene_path == "":
			errors.append("Chapter %s missing scene_path." % cid)
		elif not ResourceLoader.exists(scene_path):
			errors.append("Chapter %s scene_path not found: %s" % [cid, scene_path])
		var glb := String(c.get("imported_scene_path", ""))
		if glb == "":
			errors.append("Chapter %s missing imported_scene_path." % cid)
		elif not FileAccess.file_exists(glb):
			errors.append("Chapter %s imported_scene_path not found: %s" % [cid, glb])
		var nxt := String(c.get("next_chapter_id", ""))
		if nxt != "" and not chapters.has(nxt):
			errors.append("Chapter %s next_chapter_id missing: %s" % [cid, nxt])
		for q in c.get("quests", []):
			if not quests.has(String(q)):
				errors.append("Chapter %s references missing quest: %s" % [cid, String(q)])

	# --- Routes ---
	for rid in routes:
		var r: Dictionary = routes[rid]
		for rc in r.get("chapters", []):
			if not chapters.has(String(rc)):
				errors.append("Route %s references missing chapter: %s" % [rid, String(rc)])

	# --- Quests ---
	for qid in quests:
		var q: Dictionary = quests[qid]
		var steps: Array = q.get("steps", [])
		if steps.is_empty():
			errors.append("Quest %s has no steps." % qid)
		for step in steps:
			if not (step.has("required_flag") or step.has("required_any_flag")):
				errors.append("Quest %s step '%s' has no required flag." % [qid, String(step.get("id", "?"))])

	# --- Dialogues ---
	for did in dialogues:
		var d: Dictionary = dialogues[did]
		if not d.has("nodes"):
			continue  # auxiliary line/data table, not a branching dialogue
		var nodes: Dictionary = d["nodes"]
		if not nodes.has("start"):
			errors.append("Dialogue %s has no 'start' node." % did)
		for node_id in nodes.keys():
			var node: Dictionary = nodes[node_id]
			errors.append_array(_check_specials(node.get("special", {}), did, String(node_id)))
			var nx := String(node.get("next", ""))
			if nx != "" and nx != "end" and not nodes.has(nx):
				errors.append("Dialogue %s node '%s' next missing: %s" % [did, String(node_id), nx])
			for choice in node.get("choices", []):
				var cnx := String(choice.get("next", ""))
				if cnx != "" and cnx != "end" and not nodes.has(cnx):
					errors.append("Dialogue %s choice '%s' points to missing node '%s'." % [did, String(choice.get("id", "?")), cnx])
				errors.append_array(_check_specials(choice.get("special", {}), did, String(choice.get("id", "?"))))

	# --- Interactables ---
	for iid in interactables:
		var it: Dictionary = interactables[iid]
		var dlg := String(it.get("dialogue_id", ""))
		if dlg != "" and not dialogues.has(dlg):
			errors.append("Interactable %s dialogue_id missing: %s" % [iid, dlg])
		var ev := String(it.get("trigger_spiritual_event", ""))
		if ev != "" and not events.has(ev):
			errors.append("Interactable %s spiritual event missing: %s" % [iid, ev])
		var item := String(it.get("item_id", ""))
		if item != "" and not items.has(item):
			errors.append("Interactable %s item_id missing: %s" % [iid, item])

	# --- Companions ---
	for cmid in companions:
		var cm: Dictionary = companions[cmid]
		if String(cm.get("join_flag", "")) == "":
			errors.append("Companion %s missing join_flag." % cmid)
		if not cm.has("special_state"):
			errors.append("Companion %s missing special_state." % cmid)
		for iv in cm.get("interventions", []):
			var ivd := String(iv.get("dialogue_id", ""))
			if ivd != "" and not dialogues.has(ivd):
				errors.append("Companion %s intervention dialogue missing: %s" % [cmid, ivd])

	# --- Hazards / Enemies / Items ---
	for hid in hazards:
		if String((hazards[hid] as Dictionary).get("type", "")) == "":
			errors.append("Hazard %s missing type." % hid)
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		if String(e.get("id", "")) == "":
			errors.append("Enemy %s missing id." % eid)
		if not e.has("attack_effects") and not e.has("phases"):
			errors.append("Enemy %s missing attack_effects/phases." % eid)
	for iid2 in items:
		var item2: Dictionary = items[iid2]
		if String(item2.get("id", "")) == "" or String(item2.get("type", "")) == "":
			errors.append("Item %s missing id/type." % iid2)

	return errors


static func _check_specials(special: Dictionary, did: String, where: String) -> Array:
	var errors: Array = []
	for sp in special:
		if not SUPPORTED_SPECIALS.has(String(sp)):
			errors.append("Dialogue %s '%s' unsupported special: %s" % [did, where, String(sp)])
	return errors


static func _dup_ids(label: String, category_data: Dictionary) -> Array:
	var errors: Array = []
	var seen: Array = []
	for fid in category_data:
		var body: Dictionary = category_data[fid]
		var cid := String(body.get("id", fid))
		if seen.has(cid):
			errors.append("Duplicate %s id: %s" % [label, cid])
		seen.append(cid)
	return errors


static func report() -> String:
	var errors := validate_all_data()
	if errors.is_empty():
		return "Data validation passed."
	var s := "Data validation found %d issue(s):\n" % errors.size()
	for e in errors:
		s += " - " + String(e) + "\n"
	return s

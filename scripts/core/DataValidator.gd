extends RefCounted
class_name DataValidator
## Validates the JSON data pack. Call DataValidator.validate_all_data() to get a
## list of error strings (empty == everything is consistent).

const CHAPTER_DIR := "res://data/chapters/"
const QUEST_DIR := "res://data/quests/"
const DIALOGUE_DIR := "res://data/dialogues/"
const ENEMY_DIR := "res://data/enemies/"
const ROUTE_FILE := "res://data/route/full_route.json"


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _list_json(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return out


static func validate_all_data() -> Array:
	var errors: Array = []
	var chapter_ids: Array = []

	# --- Chapters ---
	for f in _list_json(CHAPTER_DIR):
		var data := _read(CHAPTER_DIR + f)
		var cid := String(data.get("id", ""))
		if cid == "":
			errors.append("Chapter %s missing id." % f)
			continue
		if chapter_ids.has(cid):
			errors.append("Duplicate chapter id: %s" % cid)
		chapter_ids.append(cid)
		if String(data.get("title", "")) == "":
			errors.append("Chapter %s missing title." % cid)
		var scene_path := String(data.get("scene_path", ""))
		if scene_path == "":
			errors.append("Chapter %s missing scene_path." % cid)
		elif not ResourceLoader.exists(scene_path):
			errors.append("Chapter %s scene_path not found: %s" % [cid, scene_path])

	# --- Route ---
	var route := _read(ROUTE_FILE)
	for c in route.get("chapters", []):
		if not chapter_ids.has(String(c)):
			errors.append("Route references missing chapter: %s" % String(c))

	# --- Quests ---
	var quest_ids: Array = []
	for f in _list_json(QUEST_DIR):
		var q := _read(QUEST_DIR + f)
		var qid := String(q.get("id", ""))
		if qid == "":
			errors.append("Quest %s missing id." % f)
			continue
		if quest_ids.has(qid):
			errors.append("Duplicate quest id: %s" % qid)
		quest_ids.append(qid)
		var steps: Array = q.get("steps", [])
		if steps.is_empty():
			errors.append("Quest %s has no steps." % qid)
		for step in steps:
			if not (step.has("required_flag") or step.has("required_any_flag")):
				errors.append("Quest %s step '%s' has no required flag." % [qid, String(step.get("id", "?"))])

	# --- Dialogues ---
	var dialogue_ids: Array = []
	for f in _list_json(DIALOGUE_DIR):
		var d := _read(DIALOGUE_DIR + f)
		var did := String(d.get("id", ""))
		if did != "":
			dialogue_ids.append(did)
		# promise_stone_lines is a data table, not a node graph; skip node checks.
		if not d.has("nodes"):
			continue
		var nodes: Dictionary = d["nodes"]
		if not nodes.has("start"):
			errors.append("Dialogue %s has no 'start' node." % f)
		for node_id in nodes.keys():
			var node: Dictionary = nodes[node_id]
			for choice in node.get("choices", []):
				var nxt := String(choice.get("next", ""))
				if nxt != "" and nxt != "end" and not nodes.has(nxt):
					errors.append("Dialogue %s choice '%s' points to missing node '%s'." % [f, String(choice.get("id", "?")), nxt])

	# --- Enemies ---
	for f in _list_json(ENEMY_DIR):
		var e := _read(ENEMY_DIR + f)
		if String(e.get("id", "")) == "":
			errors.append("Enemy %s missing id." % f)
		if not e.has("attack_effects") and not e.has("phases"):
			errors.append("Enemy %s missing attack_effects." % String(e.get("id", f)))

	return errors


static func report() -> String:
	var errors := validate_all_data()
	if errors.is_empty():
		return "Data validation passed."
	var s := "Data validation found %d issue(s):\n" % errors.size()
	for e in errors:
		s += " - " + e + "\n"
	return s

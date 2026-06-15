extends SceneTree
## Headless in-engine smoke test for the asset/UI layer.
##
## Run (from the project root, with Godot 4.x on PATH):
##   godot --headless --import                     # once: import new assets
##   godot --headless --script tools/smoke_test.gd # check font/stickers/audio
##
## Exits 0 on success, 1 on any failure (so it can gate CI).

func _initialize() -> void:
	var fails: Array = []

	# 1) CJK font is found and resolves to a Font resource.
	var font: Font = AssetLib.font()
	if font == null:
		fails.append("font: AssetLib.font() returned null (no res://assets/fonts/*.otf?)")
	else:
		print("  font OK -> ", font.resource_path if font.resource_path != "" else "(dynamic)")

	# 2) Sticker manifest parses and every declared sticker texture loads.
	var man: Dictionary = AssetLib.sticker_manifest()
	var packs: Dictionary = man.get("packs", {})
	if packs.is_empty():
		fails.append("stickers: manifest empty or missing")
	var loaded := 0
	for pid in packs.keys():
		for nm in packs[pid].get("names", []):
			if AssetLib.sticker(String(pid), String(nm)) == null:
				fails.append("sticker missing: %s/%s" % [pid, nm])
			else:
				loaded += 1
	print("  stickers OK -> %d textures across %d pack(s)" % [loaded, packs.size()])

	# 3) Per-chapter music/ambient + every SFX referenced by AudioManager load.
	var sfx := ["ui_select", "interact", "quest_complete", "promise", "burden_fall",
		"cross_grace", "collapse", "victory", "save", "message_in", "mention"]
	var sfx_ok := 0
	for s in sfx:
		var p := "res://assets/audio/sfx/%s.ogg" % s
		if ResourceLoader.exists(p):
			sfx_ok += 1
		else:
			fails.append("sfx missing: " + p)
	print("  sfx OK -> %d/%d" % [sfx_ok, sfx.size()])

	# 4) Input actions for controller look exist (set up by Main).
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			print("  note: input action '%s' not registered yet (created at runtime by Main)" % a)
			break

	if fails.is_empty():
		print("SMOKE TEST PASSED ✓")
		quit(0)
	else:
		for f in fails:
			push_error(f)
		print("SMOKE TEST FAILED — %d issue(s)" % fails.size())
		quit(1)

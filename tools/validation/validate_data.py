"""Data-foundation validator (Phase 1 acceptance gate).

Mirrors scripts/core/DataValidator.gd so the same checks can run headless in CI /
the sandbox where Godot is unavailable. Verifies the JSON data set is internally
consistent: routes -> chapters -> quests -> dialogues, plus per-category schema
and duplicate-id checks. Exit code is non-zero if any error is found.

    python3 tools/validation/validate_data.py
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "data"))
ROOT = os.path.normpath(os.path.join(DATA, ".."))

SUPPORTED_SPECIALS = {
    # Batch 4 dialogue specials
    "trigger_event", "start_boss", "add_companion", "remove_companion",
    "grant_armor", "grant_sword", "grant_shield", "grant_promise_key",
    "grant_shepherd_map", "grant_final_seal", "activate_prayer_light",
    "show_journey_review", "show_credits",
    # specials already handled by SpiritualStateManager._apply_special
    "remove_burden", "grant_scroll", "grant_seal", "grant_new_garment", "cross_grace",
    "remove_scroll", "remove_seal", "remove_promise_key", "remove_armor",
    "remove_sword", "remove_shield", "remove_shepherd_map", "remove_final_seal",
}


def _has_cjk(text):
    return any(0x3400 <= ord(ch) <= 0x9FFF or 0xF900 <= ord(ch) <= 0xFAFF for ch in str(text))


def _load_category(category):
    out = {}
    d = os.path.join(DATA, category)
    if not os.path.isdir(d):
        return out
    for name in sorted(os.listdir(d)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(d, name)
        try:
            with open(path, "r", encoding="utf-8") as f:
                out[name[:-5]] = json.load(f)
        except Exception as e:  # noqa: BLE001
            out[name[:-5]] = {"__parse_error__": str(e)}
    return out


def _dup_id_errors(category, items):
    errs = []
    seen = {}
    for fid, body in items.items():
        if isinstance(body, dict) and "__parse_error__" in body:
            errs.append("[%s] %s.json failed to parse: %s" % (category, fid, body["__parse_error__"]))
            continue
        cid = body.get("id", fid) if isinstance(body, dict) else fid
        if cid in seen:
            errs.append("[%s] duplicate id '%s' in %s.json and %s.json" % (category, cid, fid, seen[cid]))
        seen[cid] = fid
    return errs


def _resource_exists(path):
    if not str(path).startswith("res://"):
        return False
    return os.path.exists(os.path.join(ROOT, str(path)[6:]))


def _dialogue_can_terminate(nodes, node_id, visiting=None):
    if node_id in ("", "end"):
        return True
    if node_id not in nodes:
        return False
    visiting = set() if visiting is None else set(visiting)
    if node_id in visiting:
        return False
    visiting.add(node_id)
    node = nodes[node_id]
    if node.get("end", False):
        return True
    targets = []
    if node.get("next", ""):
        targets.append(node["next"])
    targets += [choice.get("next", "") for choice in node.get("choices", [])]
    # Nodes without an explicit branch are closed by the UI's Continue button.
    if not targets:
        return True
    return all(_dialogue_can_terminate(nodes, target, visiting) for target in targets)


def _produced_flags(chapters, dialogues):
    flags = set()
    for chapter in chapters.values():
        flags.update(chapter.get("on_start_flags", {}).keys())
        flags.update(chapter.get("on_complete_flags", {}).keys())
        for condition in chapter.get("completion_conditions", []):
            if condition.get("type", "flag") == "flag":
                flags.add(condition.get("key", ""))
    for dialogue in dialogues.values():
        for node in (dialogue.get("nodes") or {}).values():
            flags.update(node.get("set_flags", {}).keys())
            flags.update(node.get("flags", {}).keys())
            for choice in node.get("choices", []):
                flags.update(choice.get("flags", {}).keys())
    scripts_dir = os.path.join(ROOT, "scripts")
    for base, _dirs, names in os.walk(scripts_dir):
        for name in names:
            if not name.endswith(".gd"):
                continue
            text = open(os.path.join(base, name), "r", encoding="utf-8").read()
            flags.update(re.findall(r'["\']([a-z][a-z0-9_]+)["\']', text))
    return flags


def validate():
    errors = []
    routes = _load_category("route")
    chapters = _load_category("chapters")
    quests = _load_category("quests")
    dialogues = _load_category("dialogues")
    events = _load_category("spiritual_events")
    interactables = _load_category("interactables")
    hazards = _load_category("hazards")
    enemies = _load_category("enemies")
    items = _load_category("items")
    companions = _load_category("companions")

    for cat, data in [("route", routes), ("chapters", chapters), ("quests", quests),
                      ("dialogues", dialogues), ("spiritual_events", events),
                      ("interactables", interactables), ("hazards", hazards),
                      ("enemies", enemies), ("items", items), ("companions", companions)]:
        errors += _dup_id_errors(cat, data)

    # --- routes ---
    for rid, r in routes.items():
        for cid in r.get("chapters", []):
            if cid not in chapters:
                errors.append("[route:%s] references missing chapter '%s'" % (rid, cid))
        for key in ("start_chapter", "end_chapter"):
            if r.get(key) and r[key] not in chapters:
                errors.append("[route:%s] %s '%s' is not a chapter" % (rid, key, r.get(key)))

    full_route = routes.get("full_route", {}).get("chapters", [])
    if len(full_route) != len(chapters) or len(set(full_route)) != len(chapters):
        errors.append("[route:full_route] must contain every chapter exactly once")
    for i, cid in enumerate(full_route):
        if cid not in chapters:
            continue
        expected_prev = full_route[i - 1] if i > 0 else ""
        expected_next = full_route[i + 1] if i + 1 < len(full_route) else ""
        if chapters[cid].get("previous_chapter_id", "") != expected_prev:
            errors.append("[chapter:%s] previous_chapter_id does not match full_route" % cid)
        if chapters[cid].get("next_chapter_id", "") != expected_next:
            errors.append("[chapter:%s] next_chapter_id does not match full_route" % cid)

    # --- chapters ---
    for cid, c in chapters.items():
        for field in ("id", "title", "scene_path", "imported_scene_path"):
            if not c.get(field):
                errors.append("[chapter:%s] missing required field '%s'" % (cid, field))
        for field in ("scene_path", "imported_scene_path"):
            if c.get(field) and not _resource_exists(c[field]):
                errors.append("[chapter:%s] %s does not exist: %s" % (cid, field, c[field]))
        if not c.get("title_zh"):
            errors.append("[chapter:%s] missing title_zh" % cid)
        for field in ("subtitle", "spiritual_theme", "core_mechanic"):
            if c.get(field) and not c.get(field + "_zh"):
                errors.append("[chapter:%s] missing %s_zh" % (cid, field))
        intro = c.get("intro", [])
        intro_zh = c.get("intro_zh", [])
        if intro and len(intro_zh) < len(intro):
            errors.append("[chapter:%s] intro_zh has %d lines, expected %d" % (cid, len(intro_zh), len(intro)))
        nxt = c.get("next_chapter_id", "")
        if nxt and nxt not in chapters:
            errors.append("[chapter:%s] next_chapter_id '%s' does not exist" % (cid, nxt))
        prv = c.get("previous_chapter_id", "")
        if prv and prv not in chapters:
            errors.append("[chapter:%s] previous_chapter_id '%s' does not exist" % (cid, prv))
        for q in c.get("quests", []):
            if q not in quests:
                errors.append("[chapter:%s] references missing quest '%s'" % (cid, q))
        guide_path = os.path.join(DATA, "teaching_guides", cid + ".json")
        if not os.path.exists(guide_path):
            errors.append("[chapter:%s] missing teaching guide" % cid)

    produced_flags = _produced_flags(chapters, dialogues)

    # --- quests ---
    for qid, q in quests.items():
        for field in ("title", "description"):
            if q.get(field) and not q.get(field + "_zh"):
                errors.append("[quest:%s] missing %s_zh" % (qid, field))
        steps = q.get("steps", [])
        if not steps:
            errors.append("[quest:%s] has no steps" % qid)
        for i, step in enumerate(steps):
            if not step.get("required_flag") and not step.get("required_any_flag"):
                errors.append("[quest:%s] step %d lacks required_flag/required_any_flag" % (qid, i))
            if step.get("description") and not step.get("description_zh"):
                errors.append("[quest:%s] step %d missing description_zh" % (qid, i))
            required = [step.get("required_flag", "")] + list(step.get("required_any_flag", []))
            for flag in [f for f in required if f]:
                if flag not in produced_flags:
                    errors.append("[quest:%s] step %d flag '%s' is never produced" % (qid, i, flag))

    # --- dialogues ---
    for did, d in dialogues.items():
        nodes = d.get("nodes")
        if nodes is None:
            # Auxiliary data file (e.g. a promise-stone lines table), not a
            # branching dialogue -- nothing further to validate here.
            continue
        if "start" not in nodes:
            errors.append("[dialogue:%s] has no 'start' node" % did)
        for nid in sorted(nodes.keys()):
            if not _dialogue_can_terminate(nodes, nid):
                errors.append("[dialogue:%s] node '%s' has no terminating path" % (did, nid))
        valid_targets = set(nodes.keys()) | {"", "end"}
        for nid, node in nodes.items():
            if node.get("speaker") and not node.get("speaker_zh"):
                errors.append("[dialogue:%s] node '%s' missing speaker_zh" % (did, nid))
            if node.get("text") and not node.get("text_zh"):
                errors.append("[dialogue:%s] node '%s' missing text_zh" % (did, nid))
            nx = node.get("next", "")
            if nx and nx not in valid_targets:
                errors.append("[dialogue:%s] node '%s' next '%s' missing" % (did, nid, nx))
            for sp in node.get("special", {}).keys():
                if sp not in SUPPORTED_SPECIALS:
                    errors.append("[dialogue:%s] node '%s' unsupported special '%s'" % (did, nid, sp))
            for ch in node.get("choices", []):
                if ch.get("text") and not ch.get("text_zh"):
                    errors.append("[dialogue:%s] choice '%s' missing text_zh" % (did, ch.get("id", "?")))
                cnx = ch.get("next", "")
                if cnx and cnx not in valid_targets:
                    errors.append("[dialogue:%s] choice '%s' next '%s' missing" % (did, ch.get("id", "?"), cnx))
                for sp in ch.get("special", {}).keys():
                    if sp not in SUPPORTED_SPECIALS:
                        errors.append("[dialogue:%s] choice '%s' unsupported special '%s'" % (did, ch.get("id", "?"), sp))

    # --- interactables ---
    for iid, it in interactables.items():
        if it.get("dialogue_id") and it["dialogue_id"] not in dialogues:
            errors.append("[interactable:%s] dialogue_id '%s' missing" % (iid, it["dialogue_id"]))
        if it.get("trigger_spiritual_event") and it["trigger_spiritual_event"] not in events:
            errors.append("[interactable:%s] spiritual event '%s' missing" % (iid, it["trigger_spiritual_event"]))
        if it.get("item_id") and it["item_id"] not in items:
            errors.append("[interactable:%s] item_id '%s' missing" % (iid, it["item_id"]))

    # --- hazards / enemies / items / companions ---
    for hid, h in hazards.items():
        if not h.get("type"):
            errors.append("[hazard:%s] missing 'type'" % hid)
    for eid, e in enemies.items():
        if not e.get("enemy_type"):
            errors.append("[enemy:%s] missing 'enemy_type'" % eid)
        if "influence" not in e:
            errors.append("[enemy:%s] missing 'influence'" % eid)
    for iid, it in items.items():
        if not it.get("id") or not it.get("type"):
            errors.append("[item:%s] missing id/type" % iid)
    for cid, c in companions.items():
        if not c.get("join_flag"):
            errors.append("[companion:%s] missing 'join_flag'" % cid)
        if "special_state" not in c:
            errors.append("[companion:%s] missing 'special_state'" % cid)
        for iv in c.get("interventions", []):
            did = iv.get("dialogue_id")
            if did and did not in dialogues:
                errors.append("[companion:%s] intervention dialogue '%s' missing" % (cid, did))

    # --- Chinese-first runtime learning content ---
    scripture_gates_path = os.path.join(DATA, "scripture", "scripture_gates.json")
    verse_cards_path = os.path.join(DATA, "scripture", "verse_cards.json")
    scripture_gates = json.load(open(scripture_gates_path, "r", encoding="utf-8")) if os.path.exists(scripture_gates_path) else {}
    verse_cards = json.load(open(verse_cards_path, "r", encoding="utf-8")) if os.path.exists(verse_cards_path) else {}
    for cid in chapters.keys():
        gate = scripture_gates.get(cid)
        if not isinstance(gate, dict):
            errors.append("[scripture_gate:%s] missing Scripture Gate" % cid)
        else:
            for field in ("ref", "prompt", "correct", "wrong"):
                if gate.get(field) and not _has_cjk(gate[field]):
                    errors.append("[scripture_gate:%s] field '%s' has no Chinese" % (cid, field))
            for i, opt in enumerate(gate.get("options", [])):
                if not _has_cjk(opt):
                    errors.append("[scripture_gate:%s] option %d has no Chinese" % (cid, i))
        card = verse_cards.get(cid)
        if not isinstance(card, dict):
            errors.append("[verse_card:%s] missing verse card" % cid)
        else:
            for field in ("theme_zh", "memory_zh"):
                if not card.get(field):
                    errors.append("[verse_card:%s] missing %s" % (cid, field))

    counts = {
        "route": len(routes), "chapters": len(chapters), "quests": len(quests),
        "dialogues": len(dialogues), "spiritual_events": len(events),
        "interactables": len(interactables), "hazards": len(hazards),
        "enemies": len(enemies), "items": len(items), "companions": len(companions),
    }
    return errors, counts


def main():
    errors, counts = validate()
    print("Data validation report")
    print("=" * 52)
    for k, v in counts.items():
        print("  %-18s %3d files" % (k, v))
    print("-" * 52)
    if errors:
        print("FAIL: %d issue(s)" % len(errors))
        for e in errors:
            print("  - " + e)
        sys.exit(1)
    print("PASS: data validation passed (no errors).")


if __name__ == "__main__":
    main()

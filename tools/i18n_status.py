#!/usr/bin/env python3
"""Report bilingual (zh/en) coverage so the remaining work is visible. Writes
nothing. Exits 1 if there are gaps (handy for CI / tracking).

Covers:
  - Dialogue text_zh coverage per data/dialogues/*.json (nodes + choices).
  - UI keys referenced via LocaleManager.t("…") in scripts vs assets/i18n/ui.json
    (reports any key used in code but missing from the table).

Usage: python3 tools/i18n_status.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def dialogue_coverage():
    total = 0
    zh = 0
    rows = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "dialogues", "*.json"))):
        d = json.load(open(f, encoding="utf-8"))
        nt = 0
        nz = 0
        for node in d.get("nodes", {}).values():
            if str(node.get("text", "")) != "":
                nt += 1
                nz += 1 if node.get("text_zh") else 0
            for c in node.get("choices", []):
                if str(c.get("text", "")) != "":
                    nt += 1
                    nz += 1 if c.get("text_zh") else 0
        total += nt
        zh += nz
        rows.append((os.path.basename(f), nz, nt))
    return rows, zh, total


def ui_keys():
    table = json.load(open(os.path.join(ROOT, "assets", "i18n", "ui.json"), encoding="utf-8"))
    keys = set(k for k in table if not k.startswith("_"))
    used = set()
    for f in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        txt = open(f, encoding="utf-8").read()
        for m in re.finditer(r'LocaleManager\.t\(\s*"([^"]+)"', txt):
            k = m.group(1)
            if not k.endswith("."):  # skip dynamic prefixes like "npc." + name
                used.add(k)
    return keys, used, sorted(used - keys)


def main():
    rows, zh, total = dialogue_coverage()
    print("=== Dialogue zh coverage (text_zh on nodes + choices) ===")
    for name, nz, nt in rows:
        mark = "OK " if nz == nt else "    "
        print("  [%s] %-30s %d/%d" % (mark, name, nz, nt))
    print("  TOTAL  %d/%d  (%.0f%%)" % (zh, total, 100 * zh / max(total, 1)))

    keys, used, missing = ui_keys()
    print("\n=== UI translation keys ===")
    print("  table keys: %d   referenced in code: %d   missing from table: %d"
          % (len(keys), len(used), len(missing)))
    for k in missing:
        print("    MISSING:", k)

    gaps = (zh < total) or bool(missing)
    print("\n%s" % ("i18n has gaps (see above)." if gaps else "i18n complete."))
    sys.exit(1 if gaps else 0)


if __name__ == "__main__":
    main()

"""Generate the per-chapter TEMPTATION MOMENT dialogues.

    python3 tools/data_gen/build_temptation_dialogues.py

Writes data/dialogues/temptation_<chapter_id>.json for every chapter that
declares a `design.primary_temptation`.

WHY
---
Two systems already existed and had never been joined up:

  * `SpiritualStateManager.get_temptation_resistance()` computes, for ten named
    temptations, whether your CURRENT spiritual posture can withstand them
    (e.g. resisting "comfort_shortcut" = discernment + perseverance − weariness
    − deception). `DialogueManager` already supports a
    `"conditions": {"temptation": {...}}` gate on any choice.
  * `data/chapters/*.json` already carries, per chapter, a hand-authored
    `design.primary_temptation` with its `type`, the lie it whispers (`hook_zh`)
    and what would resist it (`resisted_by`).

But NOT ONE dialogue in the project used a temptation condition, so the whole
mechanism was a dead branch, and every gated choice in the game was instead a
bare `faith_min: 50`-style threshold. This generator closes that gap: each
chapter gets the moment where its characteristic lie is spoken aloud, and the
options you are offered depend on whether you can actually stand against it.

Three outcomes per moment:

  RESIST    — offered only if your posture beats the full difficulty.
  REMEMBER  — offered if you carry the thing the chapter says would help
              (`resisted_by.or_item` / `or_flag`): grace you were given
              earlier, not strength you generated.
  STRUGGLE  — offered at roughly half difficulty: you hold, but it costs.
  YIELD     — always available. Someone with nothing left can always give in,
              and the game should let them, and remember it.

That means the same conversation genuinely reads differently depending on how
you have been walking, which is the point of having a spiritual state model at
all.
"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CH_DIR = os.path.join(ROOT, "data", "chapters")
OUT_DIR = os.path.join(ROOT, "data", "dialogues")

# Per-temptation copy. The "voice" is deliberately not a character: it is the
# thought itself, which is how Bunyan writes most of these.
VOICE = {
    "return_to_city": ("A voice behind you", "身后的声音"),
    "despair":        ("The weight in your chest", "胸中的重压"),
    "comfort_shortcut": ("An easier thought", "一个轻省的念头"),
    "vanity":         ("The crowd's approval", "人群的称许"),
    "shame":          ("The accusation", "那控告"),
    "doubt":          ("A reasonable doubt", "一个合情合理的疑惑"),
    "sleep":          ("A soft drowsiness", "一阵柔软的困倦"),
    "false_teaching": ("A confident explanation", "一个笃定的解释"),
    "self_reliance":  ("Your own strength", "你自己的力量"),
    "fear":           ("The cold at your feet", "脚下的寒意"),
}

# Per-temptation choice copy: (resist_en, resist_zh, struggle_en, struggle_zh,
#                              yield_en, yield_zh, after_resist_zh,
#                              after_struggle_zh, after_yield_zh)
COPY = {
    "return_to_city": (
        "I have seen where that road ends. I am not going back.",
        "我已看见那条路的尽头。我不回去了。",
        "Part of me wants to. I keep walking anyway.",
        "我心里有一半想回去。我还是往前走。",
        "Perhaps home was not so bad after all.",
        "也许家里……其实也没那么糟。",
        "那声音散了。脚下的路没有变宽，你的心却宽了些。",
        "那声音没散，只是被你走在了身后。这样也算数。",
        "你回头望了很久。再转过身时，路显得比刚才长了。"),
    "despair": (
        "This weight is real. It is also not the last word.",
        "这重压是真的。但它不是最后的话。",
        "I cannot answer this. I can still take one more step.",
        "我答不上来。但我还能再走一步。",
        "It is right. I will never get out of this.",
        "它说得对。我永远出不去了。",
        "压力还在，却不再压着你说话。你听见自己的呼吸。",
        "你没有反驳它，只是没有停下。有时候这就是全部的胜利。",
        "你同意了它。天色仿佛低了一寸，脚也更沉了。"),
    "comfort_shortcut": (
        "The easy way is not the way. I take the climb.",
        "轻省的路不是那条路。我走这段上坡。",
        "I am tired enough to want it. I refuse it tired.",
        "我累得想要那条路。我就带着累拒绝它。",
        "Just this once. Surely one shortcut cannot matter.",
        "就这一次。抄一次近路，能有多大关系。",
        "上坡还是上坡，但你走得踏实。",
        "你拒绝时并不勇敢，只是诚实。那也够了。",
        "近路走起来很轻快——直到它不再向上。"),
    "vanity": (
        "None of this is for sale, and none of it is mine to buy.",
        "这些都不出售，我也无从买起。",
        "I want to be seen. I will not pay this price to be.",
        "我想被人看见。但我不出这个价钱。",
        "Let them see me. I have earned a little admiration.",
        "让他们看着吧。我总该配得上一点仰慕。",
        "喧闹忽然离你远了一点，像隔着一层玻璃。",
        "你还是想被看见。但你没有掏出心来换。",
        "许多眼睛转向你。它们看的不是你。"),
    "shame": (
        "I am worse than it says. The door was never opened for the worthy.",
        "我比它说的更糟。这门从来就不是为配得的人开的。",
        "I have no answer. I knock anyway.",
        "我无话可答。我还是叩门。",
        "It is right. Someone like me should not be here.",
        "它说得对。像我这样的人不该站在这里。",
        "羞愧没有消失，却不再替你决定去留。",
        "你举起手时手在抖。门内的人不在意手抖。",
        "你把手放下了。门还在那里，只是你站得更远。"),
    "doubt": (
        "I do not understand it. I have still seen it.",
        "我不明白它。但我确实看见了。",
        "I doubt, and I stay.",
        "我疑惑，但我留下。",
        "It cannot be for me. I will not presume.",
        "这不可能是给我的。我不敢僭越。",
        "疑惑还在，位置却换了：它在你旁边，不在你前面。",
        "你没有解开它，只是没有让它把你带走。",
        "你退了一步。那道光并没有跟着退。"),
    "sleep": (
        "Not here. This ground is soft for a reason.",
        "不能在这里。这地这么软，是有缘故的。",
        "My eyes are closing. I keep them open by force.",
        "我的眼睛要合上了。我硬撑着睁开。",
        "Only for a moment. I will get up again soon.",
        "就一会儿。我很快就起来。",
        "空气还是甜的，但你认出了它的甜。",
        "你撑住了，代价是接下来的路更沉。",
        "你躺下了。醒来时，光变了角度，而同伴不在身边。"),
    "false_teaching": (
        "It sounds true. It is not what I was shown.",
        "它听起来是真的。但这不是我被指示的。",
        "I cannot refute it. I do not follow it either.",
        "我驳不倒它。我也不跟着它走。",
        "That is a better explanation than the one I was given.",
        "这个解释，比我得着的那个更好。",
        "话语退去，象征还在墙上，仍旧是它本来的意思。",
        "你没有被说服，也没有被折服。中间那条窄路最难走。",
        "你带走了一个更聪明的答案，和一个更模糊的方向。"),
    "self_reliance": (
        "I came this far carried. I will not now claim I walked it alone.",
        "我是被带到这里的。我不会现在说这段路是我自己走的。",
        "I want the credit. I set it down.",
        "我想要这份功劳。我把它放下。",
        "Look how far I have come. I am strong enough now.",
        "看我走了多远。我如今够刚强了。",
        "你放下的东西比看上去重。肩膀反而松了。",
        "你放下了，但手指还留着形状。下次会更快。",
        "你站得比刚才高一点。风也因此更大一点。"),
    "fear": (
        "The water is deep. It is not deeper than the promise.",
        "水很深。但没有比那应许更深。",
        "I am afraid, and I keep my feet moving.",
        "我怕，但我的脚没有停。",
        "I am going under. There is nothing to hold.",
        "我要沉下去了。没有可抓的。",
        "水没有变浅。你却站住了。",
        "你怕着往前走。这不是不怕，这是信。",
        "你抓向四周，什么也没有抓到——直到有一只手抓住你。"),
}


def difficulty_for(resisted_by):
    """Approximate the resistance threshold from the authored `resisted_by`."""
    total = 0
    for k, v in (resisted_by or {}).items():
        if k.endswith("_min") and isinstance(v, int):
            total += v
    return max(20, total)


def build(chapter_id, data):
    design = data.get("design", {}) or {}
    pt = design.get("primary_temptation") or data.get("primary_temptation")
    if not pt:
        return None
    ttype = str(pt.get("type", ""))
    if ttype not in COPY:
        return None
    hook_zh = str(pt.get("hook_zh", ""))
    hook_en = str(pt.get("hook", hook_zh))
    resisted_by = pt.get("resisted_by", {}) or {}
    hard = difficulty_for(resisted_by)
    soft = max(10, int(round(hard * 0.55)))
    or_item = resisted_by.get("or_item")
    or_flag = resisted_by.get("or_flag")

    speaker_en, speaker_zh = VOICE.get(ttype, ("A voice", "一个声音"))
    (r_en, r_zh, s_en, s_zh, y_en, y_zh,
     after_r, after_s, after_y) = COPY[ttype]

    choices = []
    # RESIST — only when the posture actually beats this temptation.
    choices.append({
        "id": "resist",
        "conditions": {"temptation": {"type": ttype, "difficulty": hard}},
        "text": r_en, "text_zh": r_zh,
        "effects": {"faith": 5, "perseverance": 5, "discernment": 3,
                    "despair": -6, "fear": -4},
        "flags": {"resisted_%s" % chapter_id: True},
        "next": "resisted",
    })
    # REMEMBER — grace already received counts, even when strength does not.
    if or_item:
        choices.append({
            "id": "remember_item",
            "conditions": {"requires_item": str(or_item)},
            "text": "(Remember what you were given, and answer from that.)",
            "text_zh": "（想起你所领受的，就凭那个回答。）",
            "effects": {"faith": 6, "hope": 4, "humility": 3, "despair": -5},
            "flags": {"resisted_%s" % chapter_id: True},
            "next": "resisted",
        })
    if or_flag:
        choices.append({
            "id": "remember_flag",
            "conditions": {"requires_flag": str(or_flag)},
            "text": "(Remember what has already happened to you.)",
            "text_zh": "（想起那已经临到你的事。）",
            "effects": {"faith": 5, "hope": 4, "humility": 3, "shame": -6},
            "flags": {"resisted_%s" % chapter_id: True},
            "next": "resisted",
        })
    # STRUGGLE — you hold, and it costs.
    choices.append({
        "id": "struggle",
        "conditions": {"temptation": {"type": ttype, "difficulty": soft}},
        "text": s_en, "text_zh": s_zh,
        "effects": {"perseverance": 6, "weariness": 6, "faith": 2},
        "flags": {"struggled_%s" % chapter_id: True},
        "next": "struggled",
    })
    # YIELD — always available.
    choices.append({
        "id": "yield",
        "text": y_en, "text_zh": y_zh,
        "effects": {"despair": 8, "shame": 5, "faith": -4, "weariness": 4},
        "flags": {"yielded_%s" % chapter_id: True},
        "next": "yielded",
    })

    def closing(text_zh, node_id):
        return {
            "speaker": speaker_en, "speaker_zh": speaker_zh,
            "text": "", "text_zh": text_zh,
            "choices": [{"id": "on_" + node_id,
                         "text": "(Walk on.)", "text_zh": "（继续前行。）",
                         "next": "end"}],
        }

    return {
        "id": "temptation_%s" % chapter_id,
        "_comment": ("Generated by tools/data_gen/build_temptation_dialogues.py "
                     "from data/chapters/%s.json design.primary_temptation. "
                     "Choices are gated by SpiritualStateManager."
                     "can_resist_temptation()." % chapter_id),
        "nodes": {
            "start": {
                "speaker": speaker_en, "speaker_zh": speaker_zh,
                "text": hook_en, "text_zh": hook_zh,
                "choices": choices,
            },
            "resisted": closing(after_r, "resisted"),
            "struggled": closing(after_s, "struggled"),
            "yielded": closing(after_y, "yielded"),
            "end": {"speaker": "", "text": "", "end": True},
        },
    }


def main():
    written = 0
    skipped = []
    for fn in sorted(os.listdir(CH_DIR)):
        if not fn.endswith(".json"):
            continue
        cid = fn[:-5]
        with open(os.path.join(CH_DIR, fn), encoding="utf-8") as f:
            data = json.load(f)
        doc = build(cid, data)
        if doc is None:
            skipped.append(cid)
            continue
        out = os.path.join(OUT_DIR, "temptation_%s.json" % cid)
        with open(out, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write("\n")
        pt = (data.get("design", {}) or {}).get("primary_temptation", {})
        print("%-24s %-16s difficulty %d" % (
            cid, pt.get("type", "?"), difficulty_for(pt.get("resisted_by", {}))))
        written += 1
    print("-" * 60)
    print("Wrote %d temptation dialogues." % written)
    if skipped:
        print("No primary_temptation (skipped): %s" % ", ".join(skipped))


if __name__ == "__main__":
    main()

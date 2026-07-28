"""Give each Vanity Fair stall its own lie — and let earlier chapters answer it.

    python3 tools/data_gen/build_vanity_stalls.py

Writes data/dialogues/vanity_stall_<ware>.json for each of the fair's wares.

WHY
---
The fair had four stalls and ONE dialogue. Every merchant said the same generic
line ("everyone who is anyone owns one"), and the only replies were `buy` and
`refuse` — so the chapter about being sold specific things sold nothing in
particular, and the player's only tool was the word "no".

Each stall now:

  * names a SPECIFIC lie, in the grammar of its own ware;
  * offers a REBUTTAL option unlocked by something that actually happened to
    you in an earlier chapter — the Interpreter's lesson, the climb, the
    armour, the accuser you outlasted. Refusing costs nothing and teaches
    nothing; answering with what you were shown is the chapter's real verb, and
    it is only available to a player who has been paying attention;
  * reacts differently when it is answered rather than merely declined.

This is the "use the truths from earlier chapters to rebut the merchants" item
from the review, made concrete: the flags it reads are ones the earlier chapters
already set, so no new bookkeeping is introduced.
"""

from __future__ import annotations

import json
import os

ROOT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "data", "dialogues")

# ware -> everything the stall needs.
#   lie / lie_zh          : the specific pitch
#   variant               : a second pitch shown when the player is already proud
#   buy                   : effects of buying
#   rebut_flag            : flag from an earlier chapter that unlocks the answer
#   rebut_zh / rebut_en   : what the pilgrim says
#   merchant_beaten_zh    : the merchant's reply to being answered
STALLS = {
    "applause": {
        "label_zh": "众人的称许",
        "speaker_zh": "掌声摊的贩子",
        "speaker": "The Applause-Seller",
        "lie": "You have walked a long way and no one has clapped once. Buy a "
               "little of this and they will say your name kindly.",
        "lie_zh": "你走了这么远的路，没有一个人为你鼓过掌。买一点这个，他们就会好好地念你的名字。",
        "variant_zh": "像您这样有分量的人，早该被人念着名字了。只要一点点，就够了。",
        "buy": {"pride": 7, "deception": 3, "humility": -4},
        "rebut_flag": "interpreter_full",
        "rebut_en": "I was shown a room where the light did not come from anyone clapping.",
        "rebut_zh": "我看过一间屋子。那里的光，不是从掌声来的。",
        "merchant_beaten_zh": "贩子的笑僵了一瞬。「……那间屋子我知道。我不进去。」",
    },
    "comfort": {
        "label_zh": "舒适与安逸",
        "speaker_zh": "安逸摊的贩子",
        "speaker": "The Comfort-Seller",
        "lie": "Look at your feet. You have earned a soft road. This will make "
               "the rest of the way feel like the part you have already done.",
        "lie_zh": "看看你的脚。你配得一条软路。买了它，剩下的路就会像你已经走完的那样轻省。",
        "variant_zh": "您这样的人，何必与自己过不去？剩下的路，可以由它替您走。",
        "buy": {"weariness": -6, "perseverance": -8, "deception": 4},
        "rebut_flag": "reached_summit",
        "rebut_en": "I have already been offered the soft road. It went downhill the whole way.",
        "rebut_zh": "这条软路我遇见过。它一路都在往下走。",
        "merchant_beaten_zh": "贩子耸耸肩：「爬过山的人最难做生意。」",
    },
    "influence": {
        "label_zh": "势力与地位",
        "speaker_zh": "势力摊的贩子",
        "speaker": "The Influence-Seller",
        "lie": "The road does not care who you are. Here, you could be someone. "
               "One purchase and the crowd parts for you.",
        "lie_zh": "路上没有人在乎你是谁。在这里，你可以成为一个人物。买下它，人群就会为你让开。",
        "variant_zh": "您已经有了气派，只差一个名分。这个价钱，配得上您。",
        "buy": {"pride": 8, "humility": -5, "deception": 3},
        "rebut_flag": "took_armour",
        "rebut_en": "I was given armour I did not earn. I am not going to buy a name on top of it.",
        "rebut_zh": "我身上这副军装，不是我挣来的。我不会再在它上面买一个名字。",
        "merchant_beaten_zh": "贩子看了看你的护心镜，收回了手：「……那是别处的东西。」",
    },
    "flattery": {
        "label_zh": "谄媚之镜",
        "speaker_zh": "镜子摊的贩子",
        "speaker": "The Mirror-Seller",
        "lie": "Every mirror on the road has shown you what you lack. This one "
               "shows you what you are worth. Would you not rather see that?",
        "lie_zh": "这一路上的镜子，照的都是你缺的东西。这一面照的是你值多少。你不想看看吗？",
        "variant_zh": "您早该有一面配得上您的镜子了。",
        "buy": {"pride": 6, "deception": 6, "discernment": -4},
        "rebut_flag": "stood_against_accuser",
        "rebut_en": "I have already stood in front of something that told me what I was worth. It was lying too.",
        "rebut_zh": "我已经站在一个告诉我「我值多少」的东西面前了。它也在撒谎。",
        "merchant_beaten_zh": "镜面里映出你的脸，然后是贩子的。他把镜子转了过去。",
    },
}

# Rewards for answering rather than merely refusing.
REBUT_EFFECTS = {"discernment": 9, "humility": 5, "faith": 4, "deception": -6}
REFUSE_EFFECTS = {"discernment": 5, "perseverance": 3, "humility": 2}


def build(ware, spec):
    dlg_id = "vanity_stall_%s" % ware
    choices = [
        {
            "id": "rebut",
            "conditions": {"requires_flag": spec["rebut_flag"]},
            "text": spec["rebut_en"],
            "text_zh": spec["rebut_zh"],
            "effects": dict(REBUT_EFFECTS),
            "flags": {"rebutted_%s" % ware: True, "rejected_vanity_goods": True},
            "next": "answered",
        },
        {
            "id": "buy",
            "text": "Buy it. Surely one small indulgence won't cost me much.",
            "text_zh": "买下吧。区区一点放纵，想必花不了我多少。",
            "effects": dict(spec["buy"]),
            "flags": {"vanity_bought_pending": True, "compromised_at_vanity": True},
            "items": {"vanity_token": 1},
            "next": "bought",
        },
        {
            "id": "refuse",
            "text": "No. My peace is not for sale at this fair.",
            "text_zh": "不。我的平安不在这集市上出售。",
            "effects": dict(REFUSE_EFFECTS),
            "flags": {"rejected_vanity_goods": True},
            "next": "refused",
        },
    ]

    def leaf(text_zh, cid, text_en=""):
        return {
            "speaker": spec["speaker"], "speaker_zh": spec["speaker_zh"],
            "text": text_en, "text_zh": text_zh,
            "choices": [{"id": cid, "text": "(Walk on.)",
                         "text_zh": "（继续前行。）", "next": "end"}],
        }

    return {
        "id": dlg_id,
        "_comment": ("Generated by tools/data_gen/build_vanity_stalls.py. The "
                     "`rebut` choice is gated on a flag set by an EARLIER "
                     "chapter, so answering the fair requires having learned "
                     "something on the way to it."),
        "nodes": {
            "start": {
                "speaker": spec["speaker"], "speaker_zh": spec["speaker_zh"],
                "text": spec["lie"], "text_zh": spec["lie_zh"],
                "text_variants": [
                    {"conditions": {"pride_min": 55},
                     "text": spec["lie"], "text_zh": spec["variant_zh"]},
                    {"conditions": {"discernment_min": 55},
                     "text": spec["lie"],
                     "text_zh": "你的眼太清了，不好做生意。不过——" + spec["lie_zh"]},
                ],
                "choices": choices,
            },
            "answered": leaf(spec["merchant_beaten_zh"], "on_answered"),
            "bought": leaf("明智之选！好好戴着……它配得上人群，纵然配不上这条路。",
                           "on_bought",
                           "A wise purchase! Wear it well... it suits the crowd, "
                           "if not the road."),
            "refused": leaf("随你便。眯着眼的人，从来就享受不了一场好集市。",
                            "on_refused",
                            "Suit yourself. The narrow-eyed never could enjoy a "
                            "good fair."),
            "end": {"speaker": "", "text": "", "end": True},
        },
    }


def main():
    for ware, spec in STALLS.items():
        doc = build(ware, spec)
        out = os.path.join(OUT_DIR, "%s.json" % doc["id"])
        with open(out, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("%-12s lie + rebuttal gated on '%s'" % (ware, spec["rebut_flag"]))
    print("-" * 60)
    print("Wrote %d stall dialogues." % len(STALLS))


if __name__ == "__main__":
    main()

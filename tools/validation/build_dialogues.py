"""Author the remaining Batch 1-3 dialogue files (idempotent; skips any that
already exist). Pure data -- validated by tools/validation/validate_data.py.

    python3 tools/validation/build_dialogues.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DLG = os.path.normpath(os.path.join(HERE, "..", "..", "data", "dialogues"))


def end_node():
    return {"speaker": "", "text": "", "end": True}


DIALOGUES = {
    "children_fear": {
        "start": {"speaker": "Your Children", "text": "Must you go where we cannot follow?",
            "choices": [
                {"id": "love", "text": "I go so that you might one day follow.",
                 "effects": {"humility": 5, "hope": 3}, "next": "end"},
                {"id": "grief", "text": "I cannot stay, though it breaks me.",
                 "effects": {"despair": 4, "perseverance": 3}, "next": "end"}]},
        "end": end_node()},
    "pliable_in_wilderness": {
        "start": {"speaker": "Pliable", "text": "Tell me again of the city ahead. Is it bright?",
            "choices": [
                {"id": "hard", "text": "The promise is great, but the road may be hard.",
                 "effects": {"discernment": 3, "humility": 3}, "next": "reward"},
                {"id": "reward", "text": "Think only of the reward.",
                 "effects": {"hope": 3, "deception": 3}, "next": "reward"}]},
        "reward": {"speaker": "Pliable", "text": "Then I will think of the reward. That is easier than the road.", "next": "end"},
        "end": end_node()},
    "wilderness_obstinate_returns": {
        "start": {"speaker": "Obstinate", "text": "Last chance. The city still has a bed for you.",
            "choices": [
                {"id": "forward", "text": "Forward is frightening, but backward is death.",
                 "effects": {"faith": 5, "perseverance": 5, "fear": -3},
                 "flags": {"obstinate_left": True}, "next": "end"},
                {"id": "miss", "text": "I miss the city already.",
                 "effects": {"despair": 5, "fear": 5, "hope": -3},
                 "flags": {"obstinate_left": True}, "next": "end"}]},
        "end": end_node()},
    "caged_man_vision": {
        "start": {"speaker": "", "text": "A figure sits behind iron bars. The room grows colder as you look.",
            "choices": [
                {"id": "look_away", "text": "Look away quickly.", "effects": {"fear": 5}, "next": "end"},
                {"id": "listen", "text": "Stay and listen.",
                 "effects": {"discernment": 8, "watchfulness": 5, "fear": 3},
                 "flags": {"saw_cage_vision": True}, "next": "warning"},
                {"id": "never", "text": "This could never happen to me.",
                 "effects": {"pride": 10, "deception": 5}, "next": "end"}]},
        "warning": {"speaker": "Caged Figure", "text": "Small doors become locked rooms when ignored long enough.", "next": "end"},
        "end": end_node()},
    "hill_path_choice": {
        "start": {"speaker": "", "text": "Three roads meet at the hill: one steep, one easy, one wide.",
            "choices": [
                {"id": "difficulty", "text": "Take the Difficulty path.",
                 "effects": {"perseverance": 10, "faith": 5, "weariness": 5},
                 "flags": {"chose_difficulty_path": True}, "next": "end"},
                {"id": "danger", "text": "Take the flatter path marked Danger.",
                 "effects": {"deception": 10, "discernment": -5},
                 "flags": {"entered_false_path_danger": True}, "next": "false_path"},
                {"id": "destruction", "text": "Take the wide path marked Destruction.",
                 "effects": {"pride": 5, "deception": 10},
                 "flags": {"entered_false_path_destruction": True}, "next": "false_path"}]},
        "false_path": {"speaker": "", "text": "The easy road bends away from the light.",
            "choices": [{"id": "return", "text": "Return to the hard path.",
                 "effects": {"humility": 5, "deception": -5},
                 "flags": {"chose_difficulty_path": True}, "next": "end"}]},
        "end": end_node()},
    "receive_armor": {
        "start": {"speaker": "Watchman", "text": "The valley below is not empty. Take what is given.",
            "choices": [
                {"id": "thanks", "text": "Receive the armor with thanks.",
                 "effects": {"humility": 5, "faith": 5}, "flags": {"received_armor": True},
                 "special": {"grant_armor": True, "grant_sword": True, "grant_shield": True}, "next": "end"},
                {"id": "ask", "text": "Ask why armor is needed.",
                 "effects": {"discernment": 5, "watchfulness": 5}, "flags": {"received_armor": True},
                 "special": {"grant_armor": True, "grant_sword": True, "grant_shield": True}, "next": "answer"}]},
        "answer": {"speaker": "Watchman", "text": "Because some enemies speak before they strike.", "next": "end"},
        "end": end_node()},
    "apollyon_intro": {
        "start": {"speaker": "Apollyon", "text": "You fled the city, but you did not cease to be mine.",
            "choices": [
                {"id": "cross", "text": "I was burdened, but the burden fell.",
                 "effects": {"faith": 8, "shame": -5}, "flags": {"apollyon_encountered": True}, "next": "threat"},
                {"id": "fear", "text": "I am afraid of you.",
                 "effects": {"fear": 8, "humility": 3}, "flags": {"apollyon_encountered": True}, "next": "threat"},
                {"id": "pride", "text": "I can defeat you easily.",
                 "effects": {"pride": 10, "watchfulness": -5}, "flags": {"apollyon_encountered": True}, "next": "mock"}]},
        "threat": {"speaker": "Apollyon", "text": "Then stand, if you can remember what you claim.",
            "special": {"start_boss": "apollyon"}, "next": "end"},
        "mock": {"speaker": "Apollyon", "text": "Pride is a loose strap on borrowed armor.",
            "special": {"start_boss": "apollyon"}, "next": "end"},
        "end": end_node()},
    "shadow_valley_entry": {
        "start": {"speaker": "Pilgrim", "text": "I cannot see far. I can still take one step.",
            "choices": [
                {"id": "pray", "text": "Pray for light.",
                 "effects": {"fear": -10, "hope": 5, "watchfulness": 5},
                 "flags": {"used_prayer_light": True}, "special": {"activate_prayer_light": True}, "next": "echo"},
                {"id": "rush", "text": "Rush forward blindly.",
                 "effects": {"fear": 5, "weariness": 5}, "next": "end"}]},
        "echo": {"speaker": "Prayer Echo", "text": "One step is enough for this moment.", "next": "end"},
        "end": end_node()},
    "false_voice_shadow": {
        "start": {"speaker": "False Voice", "text": "This way is safer.",
            "choices": [
                {"id": "ignore", "text": "Ignore the voice and stay on the path.",
                 "effects": {"watchfulness": 5, "discernment": 5}, "flags": {"heard_false_voice": True}, "next": "end"},
                {"id": "follow", "text": "Step toward the voice.",
                 "effects": {"deception": 8, "fear": 8}, "flags": {"heard_false_voice": True}, "next": "return"},
                {"id": "pray", "text": "Stop and pray.",
                 "effects": {"hope": 5, "fear": -8}, "flags": {"used_prayer_light": True, "heard_false_voice": True},
                 "special": {"activate_prayer_light": True}, "next": "end"}]},
        "return": {"speaker": "", "text": "The voice fades. The path is behind you, not beside you.",
            "effects": {"humility": 5, "deception": -5}, "next": "end"},
        "end": end_node()},
    "merchant_applause": {
        "start": {"speaker": "Merchant of Applause", "text": "Pilgrim, you would be more useful if people liked you.",
            "choices": [
                {"id": "accept", "text": "Accept a small badge of reputation.",
                 "effects": {"pride": 8, "deception": 6, "humility": -4}, "flags": {"compromised_at_vanity": True}, "next": "cost"},
                {"id": "refuse", "text": "Refuse the badge.",
                 "effects": {"humility": 5, "discernment": 5, "pride": -3}, "flags": {"rejected_vanity_goods": True}, "next": "mock"},
                {"id": "ask", "text": "Ask what the badge costs.", "effects": {"discernment": 8}, "next": "cost"}]},
        "cost": {"speaker": "Merchant of Applause", "text": "Only a little silence when the crowd prefers it.", "next": "end"},
        "mock": {"speaker": "Merchant of Applause", "text": "Then remain strange, if you insist.", "next": "end"},
        "end": end_node()},
    "vanity_trial": {
        "start": {"speaker": "Trial Judge", "text": "You disturb the fair by desiring what we do not sell.",
            "choices": [
                {"id": "stand", "text": "Stand with Faithful.",
                 "effects": {"faith": 10, "perseverance": 8, "fear": 8},
                 "flags": {"faithful_trial_started": True, "faithful_witnessed": True}, "next": "end"},
                {"id": "silent", "text": "Stay silent in fear.",
                 "effects": {"fear": 10, "shame": 8, "humility": 3},
                 "flags": {"faithful_trial_started": True, "faithful_witnessed": True}, "next": "end"}]},
        "end": end_node()},
    "giant_despair_accusation": {
        "start": {"speaker": "Giant Despair", "text": "You have failed too often to call this a journey.",
            "choices": [
                {"id": "believe", "text": "Believe the accusation.", "effects": {"despair": 15, "shame": 10}, "next": "end"},
                {"id": "gate", "text": "I cannot see the road, but I remember the gate.",
                 "effects": {"faith": 5, "hope": 5, "shame": -5}, "next": "end"}]},
        "end": end_node()},
    "shepherds_welcome": {
        "start": {"speaker": "Shepherd Knowledge", "text": "Vision is mercy when the road has narrowed your sight.",
            "choices": [
                {"id": "look", "text": "Look long toward the city.",
                 "effects": {"hope": 15, "faith": 5},
                 "flags": {"met_shepherds": True, "saw_celestial_city_from_mountains": True}, "next": "warning"},
                {"id": "ask", "text": "Ask Hopeful what he sees.",
                 "effects": {"hope": 10, "humility": 5},
                 "flags": {"met_shepherds": True, "saw_celestial_city_from_mountains": True}, "next": "hopeful"}]},
        "hopeful": {"speaker": "Hopeful", "text": "After the castle, even green hills feel unbelievable.", "next": "warning"},
        "warning": {"speaker": "Shepherd Watchful", "text": "The next ground is not violent. That is why it is dangerous.", "next": "end"},
        "end": end_node()},
    "shepherd_warning": {
        "start": {"speaker": "Shepherd Watchful", "text": "Sleep will not attack you. It will invite you.",
            "choices": [
                {"id": "serious", "text": "Receive the warning seriously.",
                 "effects": {"watchfulness": 10, "discernment": 5},
                 "flags": {"received_shepherd_warning": True, "has_shepherd_map": True},
                 "special": {"grant_shepherd_map": True}, "next": "end"},
                {"id": "proud", "text": "We have survived worse.",
                 "effects": {"pride": 8, "watchfulness": -5},
                 "flags": {"received_shepherd_warning": True, "has_shepherd_map": True},
                 "special": {"grant_shepherd_map": True}, "next": "gentle"}]},
        "gentle": {"speaker": "Shepherd Experience", "text": "Past victories cannot keep watch for you.", "next": "end"},
        "end": end_node()},
    "testimony_recall": {
        "start": {"speaker": "Hopeful", "text": "What do you remember most clearly?",
            "choices": [
                {"id": "cross", "text": "Tell Hopeful about the burden falling.",
                 "effects": {"faith": 8, "hope": 8, "watchfulness": 5},
                 "flags": {"shared_testimony_with_hopeful": True, "resisted_sleep": True}, "next": "end"},
                {"id": "slough", "text": "Tell Hopeful about the Slough.",
                 "effects": {"humility": 8, "hope": 5, "despair": -5},
                 "flags": {"shared_testimony_with_hopeful": True, "resisted_sleep": True}, "next": "end"},
                {"id": "castle", "text": "Tell Hopeful about Doubting Castle.",
                 "effects": {"hope": 10, "faith": 5, "shame": -5},
                 "flags": {"shared_testimony_with_hopeful": True, "resisted_sleep": True}, "next": "end"}]},
        "end": end_node()},
    "river_entry": {
        "start": {"speaker": "Pilgrim", "text": "The city is near, but the river is between.",
            "choices": [
                {"id": "step", "text": "Step into the river.",
                 "effects": {"fear": 10, "faith": 5}, "flags": {"entered_river_of_death": True}, "next": "hopeful"},
                {"id": "ask", "text": "Ask Hopeful to go with you.",
                 "effects": {"humility": 5, "hope": 8}, "flags": {"entered_river_of_death": True}, "next": "hopeful"}]},
        "hopeful": {"speaker": "Hopeful", "text": "Be of good courage. I feel the bottom.", "next": "end"},
        "end": end_node()},
    "shining_ones_welcome": {
        "start": {"speaker": "Shining One", "text": "The river is behind you.",
            "choices": [
                {"id": "hopeful", "text": "Look to Hopeful.",
                 "effects": {"hope": 5, "humility": 5}, "flags": {"welcomed_by_shining_ones": True}, "next": "hopeful"},
                {"id": "gate", "text": "Look toward the gate.",
                 "effects": {"faith": 5, "hope": 5}, "flags": {"welcomed_by_shining_ones": True}, "next": "gate"}]},
        "hopeful": {"speaker": "Hopeful", "text": "We have crossed.", "next": "gate"},
        "gate": {"speaker": "Shining One", "text": "What was promised is now before you.", "next": "end"},
        "end": end_node()},
    "demo_end_reflection": {
        "start": {"speaker": "", "text": "Your burden has fallen. The road continues beyond the hill.",
            "choices": [{"id": "go", "text": "Walk on.", "effects": {"hope": 5}, "next": "end"}]},
        "end": end_node()},
}


def main():
    os.makedirs(DLG, exist_ok=True)
    created = []
    for did, nodes in DIALOGUES.items():
        path = os.path.join(DLG, did + ".json")
        if os.path.exists(path):
            continue
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"id": did, "nodes": nodes}, f, indent=2, ensure_ascii=False)
            f.write("\n")
        created.append(did)
    print("Created %d dialogue(s):" % len(created))
    for d in created:
        print("  " + d)


if __name__ == "__main__":
    main()

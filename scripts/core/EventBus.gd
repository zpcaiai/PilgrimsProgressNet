extends Node
## EventBus
## Global signal hub. All systems communicate through these signals so that
## modules stay decoupled. Autoloaded as "EventBus".

# --- Chapter / route ---
signal chapter_started(chapter_id: String)
signal chapter_completed(chapter_id: String)
signal chapter_scene_loaded(chapter_id: String)

# --- Dialogue ---
signal dialogue_started(dialogue_id: String)
signal dialogue_node_changed(node: Dictionary)
signal dialogue_ended(dialogue_id: String)
signal choice_selected(choice_id: String)

# --- Spiritual state ---
signal spiritual_state_changed(state_name: String, old_value: int, new_value: int)
signal burden_removed()
signal cross_grace_applied()
signal spiritual_collapse()
signal repentance_started()
signal repentance_completed()

# --- Quests ---
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)

# --- Interaction ---
signal interaction_available(target_id: String, prompt: String)
signal interaction_unavailable()

# --- Flow control ---
signal player_control_locked(locked: bool)
signal game_started()
signal demo_completed()

# --- Save / load ---
signal save_completed(slot_id: String)
signal load_completed(slot_id: String)

# --- Generic notification (toast text on the HUD) ---
signal notify(message: String)


func toast(message: String) -> void:
	emit_signal("notify", message)

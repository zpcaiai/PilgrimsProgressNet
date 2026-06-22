extends HazardZone
class_name FalseVoiceZone
## A voice off the path in the dark valley. Stepping into it raises deception and
## fear and marks `heard_false_voice`; staying on the lit centre line avoids it.
## Optionally starts a dialogue the first time the player drifts in.

var dialogue_id: String = ""
var _spoke: bool = false


func setup(size: Vector3, effects: Dictionary = {}, interval: float = -1.0,
		line: String = "", flag: String = "") -> void:
	super.setup(
		size,
		effects if not effects.is_empty() else {"deception": 2, "fear": 2},
		interval if interval > 0.0 else 2.0,
		line if line != "" else "A voice calls softly from the dark. Not every voice is a guide.",
		flag if flag != "" else "heard_false_voice")


func _on_player_entered() -> void:
	if dialogue_id != "" and not _spoke and not DialogueManager.is_active():
		_spoke = true
		DialogueManager.start_dialogue(dialogue_id)

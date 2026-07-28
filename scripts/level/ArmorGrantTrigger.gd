extends Area3D
class_name ArmorGrantTrigger
## Grants the whole armor (armor, sword, shield) and unlocks combat when entered.
## Built by ImportedSceneBinder from TRIGGER_ReceiveArmor. The full grant lives in
## a static helper so PROP_ArmorStand (ArmorInteractable) can reuse it.

var _granted: bool = false


static func grant_full_armor() -> void:
	if GameState.has_flag("received_armor"):
		return
	for f in ["has_armor", "has_sword", "has_shield", "received_armor",
			"took_armour", "combat_unlocked"]:
		GameState.set_flag(f, true)
	for it in ["armor", "sword", "shield"]:
		GameState.add_inventory_item(it, 1)
	SpiritualStateManager.apply_effects(
		{"faith": 10, "watchfulness": 10, "perseverance": 10})
	EventBus.toast("你为山谷穿戴军装：信心、警醒与忍耐得了坚固。")
	AudioManager.play_sfx("blessing")
	# `receive_armor.json` was written for this exact moment and referenced by
	# nothing, so the armour arrived as a toast and a stat block. Speak it.
	if DialogueManager.has_dialogue("receive_armor") and not DialogueManager.is_active():
		DialogueManager.start_dialogue("receive_armor")


func setup(size: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if _granted or not body.is_in_group("player"):
		return
	_granted = true
	grant_full_armor()

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
			"combat_unlocked"]:
		GameState.set_flag(f, true)
	for it in ["armor", "sword", "shield"]:
		GameState.add_inventory_item(it, 1)
	SpiritualStateManager.apply_effects(
		{"faith": 10, "watchfulness": 10, "perseverance": 10})
	EventBus.toast("You are clothed for the valley: faith, watchfulness, and perseverance are strengthened.")
	AudioManager.play_sfx("blessing")


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

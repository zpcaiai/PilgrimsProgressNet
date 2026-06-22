extends Interactable
class_name EquipmentPickup
## A piece of armor on display at Palace Beautiful. Interacting takes it up,
## raising the matching `has_*` flag. Built by ImportedSceneBinder from PROP_Sword
## / PROP_Shield. The visible prop mesh stays in the GLB; this only adds the
## interaction.

var item_id: String = "sword"


func setup(p_item_id: String) -> void:
	item_id = p_item_id
	one_shot = true
	prompt = "Take up the " + p_item_id
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	interact_callback = _on_take


func _on_take(_player: Node) -> void:
	GameState.set_flag("has_" + item_id, true)
	GameState.add_inventory_item(item_id, 1)
	SpiritualStateManager.apply_effects({"faith": 3, "watchfulness": 2})
	EventBus.toast("You take up the " + item_id + ".")
	EventBus.interaction_unavailable.emit()

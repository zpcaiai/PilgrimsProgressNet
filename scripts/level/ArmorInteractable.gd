extends Interactable
class_name ArmorInteractable
## The armor stand at Palace Beautiful. Examining it equips the full armor (same
## grant as TRIGGER_ReceiveArmor). Built by ImportedSceneBinder from
## PROP_ArmorStand; the GLB stand mesh remains as the visual.

func setup() -> void:
	prompt = "Take up the armor"
	one_shot = true
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	col.shape = sphere
	col.position = Vector3(0, 1.0, 0)
	add_child(col)
	interact_callback = _on_examine


func _on_examine(_player: Node) -> void:
	ArmorGrantTrigger.grant_full_armor()
	EventBus.interaction_unavailable.emit()

extends Area3D
class_name PrayerPromptTrigger
## Marks a spot in the dark valley where prayer is offered. On first entry it
## lights a temporary prayer circle (PrayerLight), eases fear, and records
## `used_prayer_light`. Built by ImportedSceneBinder from TRIGGER_PrayerPrompt.

var _used: bool = false


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
	if _used or not body.is_in_group("player"):
		return
	_used = true
	GameState.set_flag("used_prayer_light", true)
	SpiritualStateManager.apply_effects({"fear": -10, "hope": 5, "watchfulness": 5})
	EventBus.toast("You stop and pray. A small light steadies the path: one step is enough.")
	var parent := get_parent()
	if parent != null:
		PrayerLight.activate(parent, global_position)

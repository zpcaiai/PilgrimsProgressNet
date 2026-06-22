extends Area3D
class_name CrossEventTrigger
## Fires the Cross grace event when the player approaches. Built by
## ImportedSceneBinder from TRIGGER_CrossEvent and wired to a CrossEventController.

var controller: CrossEventController = null
var _fired: bool = false


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


func configure(p_controller: CrossEventController) -> void:
	controller = p_controller


func _on_enter(body: Node) -> void:
	if _fired or not body.is_in_group("player"):
		return
	_fired = true
	if controller != null:
		controller.play()

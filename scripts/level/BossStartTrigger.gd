extends Area3D
class_name BossStartTrigger
## Begins a boss fight when the player crosses into it. Finds the boss node
## (group "boss", built from an ENEMY_* marker) and calls begin(). Built by
## ImportedSceneBinder from TRIGGER_BossStart.

var boss_id: String = "apollyon"
var _started: bool = false


func setup(size: Vector3, p_boss_id: String = "apollyon") -> void:
	boss_id = p_boss_id
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
	if _started or not body.is_in_group("player"):
		return
	_started = true
	GameState.set_flag("apollyon_encountered", true)
	for boss in get_tree().get_nodes_in_group("boss"):
		if boss.has_method("begin"):
			boss.call("begin")
			return

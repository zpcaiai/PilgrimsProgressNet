extends Area3D
class_name Interactable
## Base interactable. Built procedurally by chapter scripts.
## Lives on collision layer 2 so the player's interactor (mask 2) detects it.

var prompt: String = "互动"
var interact_callback: Callable = Callable()
var one_shot: bool = false
var consumed: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func can_interact() -> bool:
	return not (one_shot and consumed)


func interact(player: Node) -> void:
	if not can_interact():
		return
	if one_shot:
		consumed = true
	AudioManager.play_sfx("interact")
	if interact_callback.is_valid():
		interact_callback.call(player)

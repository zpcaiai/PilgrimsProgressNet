extends Node3D
class_name Companion
## A travelling companion (Hopeful). Follows the player, and on a slow cadence
## speaks encouragement that eases despair and fear when they run high. Counts
## as "companion" for the Sleep Field. Persist across chapters via a GameState
## flag; chapters re-spawn the companion if that flag is set.

var companion_name: String = "Hopeful"
var _player: Node3D = null
var _timer: float = 0.0
var _offset: Vector3 = Vector3(1.6, 0, 2.2)
var _fig: Node3D
var _prev_pos: Vector3 = Vector3.ZERO

const LINES := [
	"Hopeful: \"Be of good cheer. The City stands, though clouds hide it.\"",
	"Hopeful: \"I have felt this dark too. It lied to me as well. Keep walking.\"",
	"Hopeful: \"Remember the Cross. The burden is already answered.\"",
	"Hopeful: \"One more true step, friend. I am right beside you.\"",
]


func setup(display_name: String = "Hopeful", color: Color = Color(0.6, 0.8, 0.7)) -> void:
	companion_name = display_name
	add_to_group("companion")
	# A real in-engine 3D body that walks on two legs beside you. `self` is the
	# mover whose motion drives the walk cycle (HumanoidAnimator).
	_fig = HumanoidFigure.make(display_name, 1.9, self, true, color)
	add_child(_fig)
	var label := Label3D.new()
	label.text = LocaleManager.npc_label(companion_name)
	label.position = Vector3(0, 2.1, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.outline_size = 6
	add_child(label)


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		global_position = _player.global_position + _offset
	_prev_pos = global_position


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target := _player.global_position + _offset
	global_position = global_position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	_face_travel(global_position - _prev_pos, delta)
	_prev_pos = global_position

	_timer += delta
	if _timer >= 7.0:
		_timer = 0.0
		if SpiritualStateManager.despair > 55 or SpiritualStateManager.fear > 55 or SpiritualStateManager.weariness > 60:
			SpiritualStateManager.apply_effects({"despair": -6, "fear": -4, "hope": 4})
			EventBus.toast(LINES[randi() % LINES.size()])


## Turn the 3D body to face its travel direction, so it strides forward and
## shows its back (and the back of its head) when walking away from the camera.
func _face_travel(moved: Vector3, delta: float) -> void:
	if not is_instance_valid(_fig):
		return
	if Vector2(moved.x, moved.z).length() < 0.002:
		return
	var target_yaw := atan2(moved.x, moved.z)
	_fig.rotation.y = lerp_angle(_fig.rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))

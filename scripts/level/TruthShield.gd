extends Node3D
class_name TruthShield
## Short-lived shield of faith used at the Wicket Gate. It is deliberately
## defensive: it answers accusation long enough for the pilgrim to keep moving.

const ACTIVE_TIME := 1.8
const COOLDOWN := 3.5

var _active_left: float = 0.0
var _cooldown_left: float = 0.0
var _shell: MeshInstance3D


func _ready() -> void:
	_shell = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	_shell.mesh = sphere
	_shell.position = Vector3(0, 1.05, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.36, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.25)
	mat.emission_energy_multiplier = 1.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell.material_override = mat
	_shell.visible = false
	add_child(_shell)


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_active_left = maxf(0.0, _active_left - delta)
	_shell.visible = _active_left > 0.0
	if InputManager and InputManager.context in [InputManager.CTX_GAMEPLAY, InputManager.CTX_COMBAT]:
		if Input.is_action_just_pressed(InputManager.ACTION_GUARD):
			activate()


func activate() -> bool:
	if _cooldown_left > 0.0:
		EventBus.toast("真理盾牌还在恢复；继续向门前走。")
		return false
	_active_left = ACTIVE_TIME
	_cooldown_left = COOLDOWN
	SpiritualStateManager.apply_effects({"fear": -3, "shame": -3, "faith": 1})
	EventBus.toast("你举起真理盾牌：控告不能关闭恩典之门。")
	return true


func is_active() -> bool:
	return _active_left > 0.0


func absorb_arrow(arrow_type: String) -> void:
	SpiritualStateManager.apply_effects({"fear": -4, "shame": -4, "faith": 2})
	EventBus.toast("火箭在盾牌前碎成光点：" + _type_label(arrow_type))


func _type_label(arrow_type: String) -> String:
	var labels := {
		"fear": "惧怕",
		"shame": "羞耻",
		"doubt": "疑惑",
		"delay": "拖延",
		"self_righteousness": "自义",
	}
	return String(labels.get(arrow_type, "控告"))

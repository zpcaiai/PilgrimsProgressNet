extends Node3D
class_name PlayerLight
## A lantern of faith. Added as a child of the player so it follows. Its reach
## grows with faith and shrinks with fear; praying or reading a lantern of the
## Word gives a temporary boost. Used in the dark valleys.

var _light: OmniLight3D
var boost: float = 0.0
var base_range: float = 6.0
var base_energy: float = 1.2


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.93, 0.7)
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)


func add_boost(amount: float) -> void:
	boost = min(boost + amount, 8.0)
	EventBus.toast("Light gathers around you.")


func _process(delta: float) -> void:
	boost = max(0.0, boost - delta * 1.2)
	var faith := float(SpiritualStateManager.faith)
	var fear := float(SpiritualStateManager.fear)
	_light.light_energy = clampf(base_energy + faith * 0.025 - fear * 0.02 + boost, 0.25, 8.0)
	_light.omni_range = clampf(base_range + faith * 0.12 - fear * 0.06 + boost * 2.0, 3.0, 20.0)

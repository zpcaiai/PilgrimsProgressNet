extends ChapterBase
class_name SloughOfDespond
## Chapter 3. The swamp of discouragement. Mud raises despair and slows you;
## promise stones and safe stones give relief; Pliable abandons you; Help can
## pull you out. Reach solid ground on the far side.

const PROMISE_LINES := {
	"hope": {"line": "Carved on the stone: 'Mist can hide the road, but it cannot erase it.'", "effects": {"hope": 8, "despair": -12}, "flag": "used_promise_hope"},
	"faith": {"line": "Carved on the stone: 'You do not stand because the mud is weak, but because mercy is strong.'", "effects": {"faith": 8, "fear": -6, "despair": -8}, "flag": "used_promise_faith"},
	"perseverance": {"line": "Carved on the stone: 'One true step is still obedience. Take it.'", "effects": {"perseverance": 8, "despair": -10}, "flag": "used_promise_perseverance"},
}


func _build_chapter() -> void:
	setup_environment(
		Color(0.3, 0.34, 0.32),
		Color(0.38, 0.42, 0.38),
		0.5,
		true, Color(0.45, 0.5, 0.46), 0.05
	)
	make_ground(Vector2(40, 90), Color(0.22, 0.26, 0.22))
	make_distant_light(Vector3(0, 5, -52))
	make_floating_label("Solid ground lies beyond received help", Vector3(0, 3.0, -40), Color(0.8, 0.85, 0.75))

	# Safe footing near the start.
	_add_safe_stone(Vector3(0, 0, 6))

	# Shallow mud field.
	_add_mud(Vector3(0, 1, -6), Vector3(18, 2, 16), false)

	# Promise stones (relief).
	_add_promise(Vector3(-6, 0, -6), "hope")
	_add_promise(Vector3(6, 0, -16), "faith")
	_add_promise(Vector3(0, 0, -26), "perseverance")

	# Deceptive ground in the fog.
	var fg := FalseGround.new()
	add_child(fg)
	fg.setup(Vector3(4, 0.4, 4))
	fg.position = Vector3(4, 0.2, -20)

	# Deep despair basin.
	_add_mud(Vector3(0, 1, -32), Vector3(20, 2, 14), true)
	_add_safe_stone(Vector3(-6, 0, -32))

	# Help waits at the deepest point.
	make_npc("Help", Vector3(0, 0, -38), Color(0.85, 0.85, 0.7), "help_rescue", "Reach for Help")

	# Safe path out.
	_add_safe_stone(Vector3(0, 0, -46))

	make_wayside_chapel(Vector3(-14, 0, -34), "slough", {"hope": 8, "despair": -10, "faith": 4}, "In the swamp's far corner, a dry chapel: mercy is firmer than the mud. Your heart steadies.")

	spawn_player(Vector3(0, 1, 10))

	# Pliable abandons you when you reach the mud's edge.
	make_trigger(Vector3(0, 1.5, -12), Vector3(20, 4, 2), func(_b):
		if GameState.has_flag("pliable_left"):
			return
		DialogueManager.start_dialogue("pliable_leaves")
	, true)

	# Climbing out onto the far solid ground completes the chapter.
	make_trigger(Vector3(0, 1.5, -50), Vector3(20, 4, 2), func(_b):
		GameState.set_flag("left_slough", true)
		QuestManager.update_quest_progress("escape_slough")
		EventBus.toast("You climb out onto solid ground, humbled but not abandoned.")
		_advance_after_delay()
	, false)


func _add_mud(pos: Vector3, size: Vector3, deep: bool) -> void:
	var m := MudZone.new()
	add_child(m)
	m.setup(size, deep)
	m.position = pos


func _add_safe_stone(pos: Vector3) -> void:
	var s := SafeStone.new()
	add_child(s)
	s.setup(1.6)
	s.position = pos


func _add_promise(pos: Vector3, kind: String) -> void:
	var data: Dictionary = PROMISE_LINES[kind]
	var p := PromiseStone.new()
	add_child(p)
	p.setup(String(data["line"]), data["effects"], String(data["flag"]))
	p.position = pos

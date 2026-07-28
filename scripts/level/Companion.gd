extends Node3D
class_name Companion
## A travelling companion (Hopeful) — now a relationship rather than a
## four-line loop.
##
## WHAT WAS WRONG
## --------------
## The companion had exactly four hard-coded lines, spoke one every seven
## seconds whenever any of three states was high, said the SAME things in the
## Slough as at the River, could not be answered, and slid toward a fixed offset
## through whatever geometry lay between. Two authored dialogue files written
## for him — `hopeful_keep_awake.json` and `hopeful_cell_encouragement.json` —
## were referenced by nothing at all.
##
## WHAT IT IS NOW
## --------------
##  * PER-CHAPTER VOICE. Lines come from a per-chapter bank, so Hopeful speaks
##    to where you actually are. Falls back to a by-state bank.
##  * HE READS YOU. What he says depends on which pressure is loudest —
##    despair, fear, weariness, shame or pride — not one generic threshold.
##  * YOU CAN ANSWER. Standing near him and pressing interact opens a real
##    exchange, which moves both of you. The friendship has a value (`bond`)
##    that persists and makes his words land harder.
##  * HE MOVES LIKE SOMEONE WALKING WITH YOU: a trailing follow with slack, a
##    jog when he falls behind, and a downward ray so he walks ON the ground.
##  * HE LOOKS AT YOU when he speaks.

const FOLLOW_SLACK := 2.6      # metres of rope before he closes the gap
const CATCHUP_DIST := 7.0      # beyond this he jogs
const WALK_SPEED := 3.6
const RUN_SPEED := 6.2
const SPEAK_COOLDOWN := 9.0
const TALK_RADIUS := 3.2

var companion_name: String = "Hopeful"
var bond: int = 0              # 0..100, persisted through GameState

var _player: Node3D = null
var _fig: Node3D
var _anim: HumanoidAnimator = null
var _timer: float = 0.0
var _prev_pos: Vector3 = Vector3.ZERO
var _offset: Vector3 = Vector3(1.6, 0, 2.2)
var _prompt: Label3D = null
var _last_line: String = ""
var _talk_cooldown: float = 0.0

## Lines by the pressure that is loudest in you right now. Answering the
## specific thing that is wrong is the difference between a friend and a loop.
const BY_STATE := {
	"despair": [
		"盼望：「这黑我也走过。它对我也撒了谎。再走一步。」",
		"盼望：「你现在觉得走不到，是真的。走不到，也不是靠你自己撑着。」",
	],
	"fear": [
		"盼望：「怕就怕着走。脚不停，就还在路上。」",
		"盼望：「我数着你的脚步呢。已经比你以为的远了。」",
	],
	"weariness": [
		"盼望：「累是应该的。你背过很重的东西。」",
		"盼望：「慢一点没关系，只要方向不换。」",
	],
	"shame": [
		"盼望：「你不必先干净了才配走这条路。没有人是那样上路的。」",
		"盼望：「那件事我也知道。我还在你旁边。」",
	],
	"pride": [
		"盼望：「你走得好。也别忘了是谁把你从泥里拉上来的。」",
		"盼望：「我们两个，都是被带到这里的。」",
	],
	"default": [
		"盼望：「放心吧。城还在那里，只是被云遮住了。」",
		"盼望：「再走一步真实的路，朋友。我就在你旁边。」",
	],
}

## Chapter-specific lines, tried before BY_STATE.
const BY_CHAPTER := {
	"vanity_fair": [
		"盼望：「别看那些摊子太久。看久了，价钱就变得合理。」",
		"盼望：「他们卖的东西，路上都用不上。」",
	],
	"doubting_castle": [
		"盼望：「弟兄，你记得吗——你身上一直带着一把钥匙。」",
		"盼望：「牢门是真的。巨人说的话不是。」",
	],
	"enchanted_ground": [
		"盼望：「别躺下。我们说说话，说着话就不困了。」",
		"盼望：「跟我讲讲你是怎么上路的？讲着讲着，天就亮了。」",
	],
	"river_of_death": [
		"盼望：「弟兄，我脚踩着底了！是硬的！」",
		"盼望：「抬头。别看水，看门。」",
	],
	"valley_shadow_death": [
		"盼望：「这里的声音不是从你心里出来的。别认领它们。」",
		"盼望：「灯是小的。小灯也是灯。」",
	],
	"delectable_mountains": [
		"盼望：「你看见了吗？就是那个。我们要去的就是那里。」",
	],
	"celestial_city": [
		"盼望：「我们到了。你听——他们在叫你的名字。」",
	],
}


func setup(display_name: String = "Hopeful", color: Color = Color(0.6, 0.8, 0.7)) -> void:
	companion_name = display_name
	add_to_group("companion")
	# A real in-engine 3D body that walks on two legs beside you. `self` is the
	# mover whose motion drives the walk cycle.
	_fig = FigureFactory.make(display_name, 1.9, self, true, color)
	add_child(_fig)
	_anim = HumanoidAnimator.find_in(_fig)
	var label := Label3D.new()
	label.text = LocaleManager.npc_label(companion_name)
	label.position = Vector3(0, 2.1, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.outline_size = 6
	add_child(label)

	_prompt = Label3D.new()
	_prompt.text = "[E] 与盼望说话"
	_prompt.position = Vector3(0, 2.45, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.007
	_prompt.outline_size = 6
	_prompt.modulate = Color(0.85, 0.95, 0.85)
	_prompt.visible = false
	add_child(_prompt)


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		global_position = _player.global_position + _offset
	_prev_pos = global_position
	bond = GameState.get_temporary_meter("companion_bond")
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_follow(delta)
	_speak(delta)
	if _talk_cooldown > 0.0:
		_talk_cooldown -= delta
	if _prompt != null:
		_prompt.visible = _in_talk_range() and not DialogueManager.is_active()


# ----------------------------------------------------------------- following

func _follow(delta: float) -> void:
	var target: Vector3 = _player.global_position + _offset
	var to: Vector3 = target - global_position
	to.y = 0.0
	var dist := to.length()
	# Rope, not rubber band: he only closes when there is real slack, so he
	# reads as walking WITH you rather than being dragged behind you.
	if dist > FOLLOW_SLACK:
		var speed := RUN_SPEED if dist > CATCHUP_DIST else WALK_SPEED
		var step: float = minf(speed * delta, dist - FOLLOW_SLACK * 0.6)
		global_position += to.normalized() * step
	# Keep his feet on the floor: without this he glides at whatever height he
	# happened to spawn at, straight through hills and stairs.
	_stick_to_ground()
	_face_travel(global_position - _prev_pos, delta)
	_prev_pos = global_position


func _stick_to_ground() -> void:
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	if space == null:
		return
	var from := global_position + Vector3(0, 2.0, 0)
	var to := global_position - Vector3(0, 4.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		var y: float = (hit["position"] as Vector3).y
		global_position.y = lerpf(global_position.y, y, 0.35)


## Turn the 3D body to face its travel direction — or the pilgrim, when they are
## standing together.
func _face_travel(moved: Vector3, delta: float) -> void:
	if not is_instance_valid(_fig):
		return
	if _in_talk_range() and Vector2(moved.x, moved.z).length() < 0.02:
		var to: Vector3 = _player.global_position - global_position
		if Vector2(to.x, to.z).length() > 0.05:
			_fig.rotation.y = lerp_angle(_fig.rotation.y, atan2(to.x, to.z),
				clampf(delta * 6.0, 0.0, 1.0))
		return
	if Vector2(moved.x, moved.z).length() < 0.002:
		return
	_fig.rotation.y = lerp_angle(_fig.rotation.y, atan2(moved.x, moved.z),
		clampf(delta * 10.0, 0.0, 1.0))


# -------------------------------------------------------------------- speech

func _speak(delta: float) -> void:
	_timer += delta
	if _timer < SPEAK_COOLDOWN:
		return
	var state := _loudest_state()
	if state == "":
		return
	_timer = 0.0
	SpiritualStateManager.apply_effects(_relief_for(state))
	EventBus.toast(_pick_line(state))
	if _anim != null and is_instance_valid(_player):
		_anim.look_at_node(_player as Node3D)
		_anim.nudge(0.05)


## Which pressure is loudest right now — or "" when the pilgrim is doing fine
## and does not need to be talked at.
func _loudest_state() -> String:
	var candidates := {
		"despair": SpiritualStateManager.despair,
		"fear": SpiritualStateManager.fear,
		"weariness": SpiritualStateManager.weariness,
		"shame": SpiritualStateManager.shame,
		"pride": SpiritualStateManager.pride,
	}
	var best := ""
	var best_v := 52
	for k in candidates.keys():
		if int(candidates[k]) > best_v:
			best_v = int(candidates[k])
			best = String(k)
	return best


func _relief_for(state: String) -> Dictionary:
	# A stronger bond makes his words land harder — friendship compounds.
	var k := 1.0 + clampf(float(bond) / 100.0, 0.0, 1.0) * 0.8
	match state:
		"despair":
			return {"despair": int(-7 * k), "hope": int(5 * k)}
		"fear":
			return {"fear": int(-7 * k), "faith": int(4 * k)}
		"weariness":
			return {"weariness": int(-6 * k), "perseverance": int(4 * k)}
		"shame":
			return {"shame": int(-7 * k), "humility": int(3 * k)}
		"pride":
			return {"pride": int(-6 * k), "humility": int(5 * k)}
		_:
			return {"hope": int(4 * k)}


func _pick_line(state: String) -> String:
	var bank: Array = BY_CHAPTER.get(String(ChapterManager.current_chapter_id), [])
	if bank.is_empty():
		bank = BY_STATE.get(state, BY_STATE["default"])
	# Never repeat the previous line back to back.
	var line := String(bank[randi() % bank.size()])
	if bank.size() > 1 and line == _last_line:
		line = String(bank[(bank.find(line) + 1) % bank.size()])
	_last_line = line
	return line


# ------------------------------------------------------------- conversation

func _in_talk_range() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return global_position.distance_to(_player.global_position) <= TALK_RADIUS


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action("interact"):
		return
	if not event.is_action_pressed("interact"):
		return
	if not _in_talk_range() or DialogueManager.is_active() or _talk_cooldown > 0.0:
		return
	get_viewport().set_input_as_handled()
	_open_exchange()


## The exchange. Prefers a chapter-specific authored dialogue where one exists —
## including `hopeful_keep_awake` and `hopeful_cell_encouragement`, which were
## written for exactly this purpose and had never been referenced by any code.
func _open_exchange() -> void:
	_talk_cooldown = 2.0
	var cid := String(ChapterManager.current_chapter_id)
	var authored := {
		"enchanted_ground": "hopeful_keep_awake",
		"doubting_castle": "hopeful_cell_encouragement",
	}
	var dlg := String(authored.get(cid, ""))
	if dlg != "" and DialogueManager.has_dialogue(dlg):
		_bond_up(4)
		DialogueManager.start_dialogue(dlg)
		return
	if DialogueManager.has_dialogue("hopeful_walking"):
		_bond_up(3)
		DialogueManager.start_dialogue("hopeful_walking")
		return
	# No authored file: the exchange still has to mean something.
	_bond_up(2)
	SpiritualStateManager.apply_effects({"hope": 4, "despair": -4, "love": 3})
	var st := _loudest_state()
	EventBus.toast(_pick_line(st if st != "" else "default"))


func _bond_up(amount: int) -> void:
	bond = clampi(bond + amount, 0, 100)
	GameState.set_temporary_meter("companion_bond", bond)
	if bond >= 40 and not GameState.has_flag("hopeful_true_friend"):
		GameState.set_flag("hopeful_true_friend", true)
		EventBus.toast("你和盼望之间，已经不只是同路了。")

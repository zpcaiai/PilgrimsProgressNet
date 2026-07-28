extends Node3D
class_name AccusationCard
## One of Apollyon's accusations, drifting toward the pilgrim as a card he can
## answer.
##
## Phase 2 of the fight used to differ from phase 1 only in the NUMBERS applied
## by `_attack()` — same behaviour, same cadence, a different dictionary. The
## fight's whole premise ("you win by standing firm and answering with promises,
## not by damage") had no expression in play.
##
## An accusation is now a physical object in the arena. It drifts in, it names
## a specific charge, and it lands on you if you ignore it. You answer it by
## being near it and pressing the interact / pray key, which costs a promise
## charge and removes more of Apollyon's influence than a generic counter — but
## the RIGHT answer (the promise that matches the charge) is worth double, so
## the player who has actually been reading the Scripture cards is rewarded for
## it rather than for reflexes.

signal answered(correct: bool)
signal landed()

const DRIFT_SPEED := 2.1
const LIFETIME := 7.5
const ANSWER_RADIUS := 3.4

var charge_id: String = "unworthy"
var text_zh: String = ""
var answer_zh: String = ""
var effects_on_land: Dictionary = {"shame": 8}
var target: Node3D = null

var _t: float = 0.0
var _resolved := false
var _label: Label3D = null
var _panel: MeshInstance3D = null


## The five charges Apollyon actually makes in Bunyan, each with the promise
## that answers it. `truth` names the Scripture card id (data/scripture) that
## counts as the matching answer.
const CHARGES := {
	"unworthy": {
		"zh": "你本是我的子民，凭什么离开我？",
		"answer_zh": "我已被赎，不再属你。",
		"truth": "redeemed",
		"effects": {"shame": 9, "faith": -3},
	},
	"failure": {
		"zh": "你在绝望泥潭里几乎淹死——那才是真正的你。",
		"answer_zh": "我跌倒过，也被拉起来过。",
		"truth": "lifted",
		"effects": {"despair": 9, "hope": -3},
	},
	"secret": {
		"zh": "你心里那件事，没有人知道。我知道。",
		"answer_zh": "已经认了的，不再定罪。",
		"truth": "forgiven",
		"effects": {"shame": 10, "despair": 4},
	},
	"abandoned": {
		"zh": "你的王从不来救你。你叫过，祂听见了吗？",
		"answer_zh": "祂的沉默不是祂的缺席。",
		"truth": "present",
		"effects": {"despair": 8, "faith": -4},
	},
	"pointless": {
		"zh": "走到最后又如何？前面还有一条你过不去的河。",
		"answer_zh": "那条河的对岸有人等我。",
		"truth": "hope_beyond",
		"effects": {"fear": 9, "hope": -4},
	},
}


static func make(charge: String, from_pos: Vector3, player: Node3D) -> AccusationCard:
	var c := AccusationCard.new()
	c.charge_id = charge
	var spec: Dictionary = CHARGES.get(charge, CHARGES["unworthy"])
	c.text_zh = String(spec.get("zh", ""))
	c.answer_zh = String(spec.get("answer_zh", ""))
	c.effects_on_land = spec.get("effects", {"shame": 8})
	c.target = player
	c.position = from_pos
	return c


func _ready() -> void:
	add_to_group("accusation_card")
	_build_visual()
	set_process(true)


func _build_visual() -> void:
	_panel = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 1.3)
	_panel.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.03, 0.05, 0.86)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.emission_enabled = true
	m.emission = Color(0.6, 0.1, 0.12)
	m.emission_energy_multiplier = 0.55
	_panel.material_override = m
	add_child(_panel)

	_label = Label3D.new()
	_label.text = text_zh
	_label.width = 420.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.font_size = 34
	_label.pixel_size = 0.0045
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.85, 0.82)
	_label.outline_size = 8
	_label.position = Vector3(0, 0, 0.02)
	add_child(_label)


func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	if target != null and is_instance_valid(target):
		var to: Vector3 = target.global_position + Vector3(0, 1.5, 0) - global_position
		var d := to.length()
		if d < 1.0:
			_land()
			return
		global_position += to.normalized() * DRIFT_SPEED * delta
	# A card that is never answered still lands — ignoring an accusation is not
	# the same as refuting it.
	if _t >= LIFETIME:
		_land()


## Called by PlayerCombat when the player answers while this card is closest.
## `promise_id` is the Scripture card used; the matching one is worth double.
func answer(promise_id: String = "") -> bool:
	if _resolved:
		return false
	_resolved = true
	var spec: Dictionary = CHARGES.get(charge_id, {})
	var correct := promise_id != "" and promise_id == String(spec.get("truth", ""))
	EventBus.toast(("「%s」—— 正是这句。" if correct else "「%s」") % answer_zh)
	SpiritualStateManager.apply_effects({
		"faith": 6 if correct else 3,
		"hope": 4 if correct else 2,
		"shame": -8 if correct else -4,
	})
	answered.emit(correct)
	_dissolve(Color(1.0, 0.95, 0.7))
	return correct


func _land() -> void:
	if _resolved:
		return
	_resolved = true
	SpiritualStateManager.apply_effects(effects_on_land)
	EventBus.toast("那句控告落在你身上。")
	Juice.shake(0.35)
	Juice.flash(Color(0.5, 0.05, 0.08, 0.2), 0.3)
	landed.emit()
	_dissolve(Color(0.6, 0.1, 0.12))


func _dissolve(tint: Color) -> void:
	set_process(false)
	if _panel != null and _panel.material_override is StandardMaterial3D:
		var m := _panel.material_override as StandardMaterial3D
		m.emission = tint
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.35)
	if _label != null:
		tw.tween_property(_label, "modulate:a", 0.0, 0.35)
	if _panel != null:
		tw.tween_property(_panel, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(queue_free)


## The card nearest the player within answering range, if any.
static func nearest_to(player: Node3D, tree: SceneTree) -> AccusationCard:
	if player == null or tree == null:
		return null
	var best: AccusationCard = null
	var best_d := ANSWER_RADIUS
	for n in tree.get_nodes_in_group("accusation_card"):
		if not (n is AccusationCard):
			continue
		var c := n as AccusationCard
		if c._resolved:
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

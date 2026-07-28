extends Node3D
class_name CloudOfWitnesses
## A wall of pilgrims who walked this road before you — spatial narrative for
## the Palace Beautiful and the Interpreter's House.
##
## Both chapters are ABOUT the communion of the saints and the record of what
## God has done, and both delivered that as a single one-shot interactable that
## printed a line of text. This turns it into a place: portraits hung along a
## wall, each dark until you come near, each brightening and naming itself as
## you pass, and one of them — chosen from what YOU have already done — showing
## a flashback of someone else living out the same virtue you just practised.
##
## Purely additive: give it a wall origin, a direction and a count.

const NEAR := 3.4          # metres at which a portrait wakes
const LIT := Color(1.0, 0.94, 0.76)
const DIM := Color(0.22, 0.20, 0.20)

## name, the virtue they are remembered for, and what they say when you pass.
const WITNESSES := [
	{"zh": "亚伯", "virtue": "faith", "line": "「他虽然死了，却因这信仍旧说话。」"},
	{"zh": "以诺", "virtue": "watchfulness", "line": "「与神同行——不过是每天不走开。」"},
	{"zh": "挪亚", "virtue": "perseverance", "line": "「我造了一百二十年。没有人相信过一句。」"},
	{"zh": "亚伯拉罕", "virtue": "faith", "line": "「我出去的时候，还不知道往哪里去。」"},
	{"zh": "撒拉", "virtue": "hope", "line": "「我笑过。祂还是守住了话。」"},
	{"zh": "约瑟", "virtue": "humility", "line": "「你们的意思是要害我，神的意思原是好的。」"},
	{"zh": "摩西", "virtue": "humility", "line": "「我宁可和神的百姓同受苦害。」"},
	{"zh": "喇合", "virtue": "faith", "line": "「我是这城里最不配的那一个。绳子还是垂下来了。」"},
	{"zh": "路得", "virtue": "love", "line": "「你往哪里去，我也往那里去。」"},
	{"zh": "大卫", "virtue": "repentance", "line": "「我犯了罪。我没有别处可去。」"},
	{"zh": "以利亚", "virtue": "perseverance", "line": "「我求死。祂给了我饼和睡眠。」"},
	{"zh": "但以理", "virtue": "watchfulness", "line": "「窗户照常开着，向着耶路撒冷。」"},
	{"zh": "司提反", "virtue": "hope", "line": "「我看见天开了。」"},
	{"zh": "保罗", "virtue": "perseverance", "line": "「那美好的仗我已经打过了。」"},
]

## Flags the player may have earned, and the virtue each one demonstrates. Used
## to pick the portrait that flashes back to something YOU did.
const FLAG_VIRTUE := {
	"accepted_help": "humility",
	"burden_fallen": "faith",
	"interpreter_full": "watchfulness",
	"reached_summit": "perseverance",
	"took_armour": "humility",
	"defeated_apollyon": "perseverance",
	"stood_against_accuser": "faith",
	"rejected_vanity_goods": "watchfulness",
	"prayed_with_hopeful": "love",
	"asked_after_hopeful": "love",
	"found_promise_key": "hope",
	"resisted_sleep": "watchfulness",
}

var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.RIGHT
var spacing: float = 2.6
var count: int = 8
var height: float = 2.05
var facing_yaw: float = 0.0

var _panels: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _specs: Array = []
var _woken: Array[bool] = []
var _player: Node3D = null
var _mirror_index: int = -1


static func build(parent: Node3D, at: Vector3, along: Vector3, n: int = 8,
		yaw: float = 0.0) -> CloudOfWitnesses:
	var c := CloudOfWitnesses.new()
	c.origin = at
	c.direction = along.normalized()
	c.count = n
	c.facing_yaw = yaw
	parent.add_child(c)
	return c


func _ready() -> void:
	position = Vector3.ZERO
	_pick_witnesses()
	_build_panels()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


## Choose which saints hang here. One slot is reserved for a witness whose
## virtue matches something the player has actually done, so the wall is partly
## a mirror.
func _pick_witnesses() -> void:
	var earned: Array[String] = []
	for f in FLAG_VIRTUE.keys():
		if GameState.has_flag(String(f)):
			earned.append(String(FLAG_VIRTUE[f]))
	var pool := WITNESSES.duplicate()
	pool.shuffle()
	_specs = pool.slice(0, mini(count, pool.size()))
	if earned.is_empty():
		return
	var want: String = earned[randi() % earned.size()]
	for i in range(_specs.size()):
		if String((_specs[i] as Dictionary).get("virtue", "")) == want:
			_mirror_index = i
			return
	# None of the chosen matched: swap one in from the full list.
	for w in WITNESSES:
		if String((w as Dictionary).get("virtue", "")) == want:
			_specs[0] = w
			_mirror_index = 0
			return


func _build_panels() -> void:
	for i in range(_specs.size()):
		var spec: Dictionary = _specs[i]
		var at := origin + direction * (spacing * (float(i) - float(_specs.size() - 1) * 0.5))
		at.y = height

		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.35, 1.85)
		panel.mesh = quad
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.14, 0.12, 0.12)
		m.emission_enabled = true
		m.emission = DIM
		m.emission_energy_multiplier = 0.25
		m.rim_enabled = true
		m.rim = 0.4
		panel.material_override = m
		panel.position = at
		panel.rotation.y = facing_yaw
		add_child(panel)
		_panels.append(panel)

		var frame := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(1.55, 2.05, 0.10)
		frame.mesh = fb
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.30, 0.24, 0.16)
		fm.roughness = 0.7
		frame.material_override = fm
		frame.position = at - Vector3(0, 0, 0.06).rotated(Vector3.UP, facing_yaw)
		frame.rotation.y = facing_yaw
		add_child(frame)

		var label := Label3D.new()
		label.text = String(spec.get("zh", ""))
		label.font_size = 40
		label.pixel_size = 0.006
		label.outline_size = 7
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.6, 0.58, 0.55, 0.5)
		label.position = at - Vector3(0, 1.25, 0)
		add_child(label)
		_labels.append(label)
		_woken.append(false)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p: Vector3 = _player.global_position
	for i in range(_panels.size()):
		if _woken[i]:
			continue
		var panel := _panels[i]
		if not is_instance_valid(panel):
			continue
		if panel.global_position.distance_to(p) > NEAR:
			continue
		_wake(i)


func _wake(i: int) -> void:
	_woken[i] = true
	var spec: Dictionary = _specs[i]
	var panel := _panels[i]
	var label := _labels[i]
	var m := panel.material_override as StandardMaterial3D
	if m != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "emission", LIT, 0.6)
		tw.tween_property(m, "emission_energy_multiplier", 1.25, 0.6)
	if is_instance_valid(label):
		var tw2 := create_tween()
		tw2.tween_property(label, "modulate:a", 1.0, 0.5)

	EventBus.toast("%s：%s" % [String(spec.get("zh", "")), String(spec.get("line", ""))])
	SpiritualStateManager.apply_effects({"hope": 2, "faith": 1})

	if i == _mirror_index:
		# The flashback: someone else living out the very thing you did.
		await get_tree().create_timer(2.4).timeout
		if not is_inside_tree():
			return
		EventBus.toast("你忽然明白：你在路上做过的那件事，正是这幅画像里的人做过的。")
		SpiritualStateManager.apply_effects({"hope": 6, "humility": 4, "shame": -5})
		GameState.set_flag("saw_the_redeemed", true)

	# Passing the whole wall is worth marking.
	if not _woken.has(false):
		GameState.set_flag("walked_the_cloud", true)
		EventBus.toast("整面墙都亮了。你不是第一个走这条路的人，也不会是最后一个。")
		SpiritualStateManager.apply_effects({"hope": 8, "faith": 5, "despair": -6})

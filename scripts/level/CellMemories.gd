extends Node3D
class_name CellMemories
## The memory of the cell — Doubting Castle's search for the Key of Promise.
##
## The key used to be one interactable in a corner: walk over, pick up, leave.
## The chapter's whole point — that the way out was in his own coat the entire
## time, and he had simply forgotten — happened in a toast.
##
## It is now a search you walk. Four shades stand in the dark of the cell, each
## one a failure from EARLIER IN THIS PLAYTHROUGH (read from your own flags, so
## a player who never fell into the Slough is not shown the Slough). Walking
## into a shade replays what it says about you, and then what grace already
## said back. When the last one has been answered, the pilgrim remembers what
## he has been carrying, and the key becomes takeable.
##
## Nothing here is a puzzle to solve. It is a sequence to walk, which is what
## remembering actually feels like.

const NEAR := 2.6

## flag -> the shade it raises. `truth` is what already answered it.
const SHADES := [
	{"flag": "yielded_slough_of_despond", "zh": "你在泥里差点淹死。",
	 "truth": "有人下到泥里，把你拉了上来。"},
	{"flag": "yielded_hill_difficulty", "zh": "你选了那条平路。",
	 "truth": "你还是回到了正路上，而且没有独自回来。"},
	{"flag": "compromised_at_vanity", "zh": "你在集市上买下了那件东西。",
	 "truth": "它已经被你放在河边了——或者会被放下。"},
	{"flag": "slept_on_enchanted_ground", "zh": "你在该儆醒的地方睡着了。",
	 "truth": "叫醒你的，不是你自己。"},
	{"flag": "lost_scroll_at_arbor", "zh": "你把书卷丢了，还回头去找。",
	 "truth": "回头去找，也是路的一部分。"},
	{"flag": "yielded_wicket_gate", "zh": "你站在门外，觉得自己不配敲。",
	 "truth": "门还是开了。它从来不是为配得的人开的。"},
	# Always available, so the sequence is never empty for a flawless run.
	{"flag": "", "zh": "你从来没有真正相信过自己走得到。",
	 "truth": "走得到，本来就不是靠你相信自己。"},
	{"flag": "", "zh": "这一路上，你数过多少次要不要回去？",
	 "truth": "数过，也没有回去。那就是答案。"},
]

const MAX_SHADES := 4

var _shades: Array[Node3D] = []
var _specs: Array = []
var _seen: Array[bool] = []
var _player: Node3D = null
var _key_node: Node3D = null
var _done := false

signal remembered()


static func build(parent: Node3D, centre: Vector3, radius: float = 4.2) -> CellMemories:
	var c := CellMemories.new()
	parent.add_child(c)
	c.global_position = centre
	c._layout(radius)
	return c


func _layout(radius: float) -> void:
	# Prefer the player's OWN failures; top up with the universal ones.
	var mine: Array = []
	var general: Array = []
	for s in SHADES:
		var f := String((s as Dictionary).get("flag", ""))
		if f == "":
			general.append(s)
		elif GameState.has_flag(f):
			mine.append(s)
	mine.shuffle()
	general.shuffle()
	_specs = mine.slice(0, MAX_SHADES)
	while _specs.size() < mini(MAX_SHADES, mine.size() + general.size()) and not general.is_empty():
		_specs.append(general.pop_back())
	if _specs.is_empty():
		_specs = general.slice(0, 2)

	for i in range(_specs.size()):
		var ang := TAU * float(i) / float(maxi(1, _specs.size()))
		var at := Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		_shades.append(_make_shade(at, String((_specs[i] as Dictionary).get("zh", ""))))
		_seen.append(false)


func _make_shade(at: Vector3, _text: String) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	# A figure of smoke: a dim, emissive column with a suggestion of a head.
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.42
	cyl.height = 1.7
	cyl.radial_segments = QualityTier.segments(10, 6)
	body.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.10, 0.14, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.30, 0.26, 0.44)
	m.emission_energy_multiplier = 0.45
	m.rim_enabled = true
	m.rim = 0.6
	body.material_override = m
	body.position = Vector3(0, 0.9, 0)
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.20
	sp.height = 0.40
	sp.radial_segments = QualityTier.segments(12, 6)
	sp.rings = QualityTier.segments(6, 4)
	head.mesh = sp
	head.material_override = m
	head.position = Vector3(0, 1.95, 0)
	root.add_child(head)
	return root


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
	EventBus.toast("牢里有影子。走过去，看清它们说的是什么。")


## Tell the sequence where the key is, so it can reveal it at the end.
func bind_key(node: Node3D) -> void:
	_key_node = node
	if is_instance_valid(_key_node):
		_key_node.visible = false


func _process(_delta: float) -> void:
	if _done or _player == null or not is_instance_valid(_player):
		return
	for i in range(_shades.size()):
		if _seen[i] or not is_instance_valid(_shades[i]):
			continue
		if _shades[i].global_position.distance_to(_player.global_position) > NEAR:
			continue
		_answer(i)


func _answer(i: int) -> void:
	_seen[i] = true
	var spec: Dictionary = _specs[i]
	EventBus.toast("影子说：「%s」" % String(spec.get("zh", "")))
	SpiritualStateManager.apply_effects({"shame": 4, "despair": 3})
	var shade := _shades[i]
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	EventBus.toast("你想起来：%s" % String(spec.get("truth", "")))
	SpiritualStateManager.apply_effects({"shame": -9, "despair": -9, "hope": 6, "faith": 4})
	if is_instance_valid(shade):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(shade, "scale", Vector3(1.4, 1.4, 1.4), 0.8)
		for c in shade.get_children():
			if c is MeshInstance3D:
				var mm := (c as MeshInstance3D).material_override as StandardMaterial3D
				if mm != null:
					tw.tween_property(mm, "albedo_color:a", 0.0, 0.8)
		tw.chain().tween_callback(shade.queue_free)
	if not _seen.has(false):
		_remember()


## "I have had it in my bosom all this while."
func _remember() -> void:
	if _done:
		return
	_done = true
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	EventBus.toast("你伸手摸自己的怀里——钥匙一直在那里。你从头到尾都带着它。")
	SpiritualStateManager.apply_effects({"hope": 14, "faith": 10, "despair": -20})
	GameState.set_flag("recalled_promise_in_cell", true)
	if is_instance_valid(_key_node):
		_key_node.visible = true
		var tw := create_tween()
		tw.tween_property(_key_node, "scale", Vector3(1.25, 1.25, 1.25), 0.4)
		tw.tween_property(_key_node, "scale", Vector3.ONE, 0.3)
	remembered.emit()

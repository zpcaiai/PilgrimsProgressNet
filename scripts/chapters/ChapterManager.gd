extends Node
## ChapterManager
## Owns the linear pilgrimage route, loads chapter data JSON, and swaps the
## active chapter scene. Autoloaded as "ChapterManager".

const CHAPTER_DIR := "res://data/chapters/"

const CHAPTER_TITLE_ZH := {
	"city_of_destruction": "灭亡城",
	"wilderness_road": "旷野之路",
	"slough_of_despond": "绝望泥潭",
	"wicket_gate": "窄门",
	"cross_and_tomb": "十字架与空墓",
	"interpreter_house": "释经者之家",
	"hill_difficulty": "艰难山",
	"palace_beautiful": "美宫",
	"valley_humiliation": "谦卑谷",
	"valley_shadow_death": "死荫谷",
	"vanity_fair": "虚华市集",
	"doubting_castle": "怀疑城堡",
	"delectable_mountains": "可悦山",
	"enchanted_ground": "迷睡之地",
	"river_of_death": "死河",
	"celestial_city": "天城",
}

const CHAPTER_SUBTITLE_ZH := {
	"city_of_destruction": "在家也无法卸下的重担中醒来",
	"wilderness_road": "旧生命的声音仍在身后追赶",
	"slough_of_despond": "罪疚使人下沉，骄傲拒绝伸来的手",
	"wicket_gate": "控告飞来时仍然叩门",
	"cross_and_tomb": "罪疚在恩典前得到回答",
	"interpreter_house": "房间教导人心如何观看",
	"hill_difficulty": "真实的路常更艰难，也更值得走",
	"palace_beautiful": "使勇气重新预备的安息",
	"valley_humiliation": "旧主人要求你回去的地方",
	"valley_shadow_death": "看不见时仍然行走",
	"vanity_fair": "把灵魂标价太低的闪亮世界",
	"doubting_castle": "被遗忘的应许成为出路",
	"delectable_mountains": "清明空气、智慧劝戒与远方家乡",
	"enchanted_ground": "像安慰一样靠近的危险",
	"river_of_death": "被迎接前最后的交托",
	"celestial_city": "整条路所应许的欢迎",
}

const CHAPTER_THEME_ZH := {
	"city_of_destruction": "醒悟、诚实的惧怕，以及第一次转向生命",
	"wilderness_road": "离开旧生命，并学习诚实回应人的反对与软弱",
	"slough_of_despond": "在绝望中承认需要，并抓住应许与帮助",
	"wicket_gate": "在控告中祈求怜悯，进入窄门",
	"cross_and_tomb": "恩典卸下重担，赐下新的身份",
	"interpreter_house": "借真理训练眼光，分辨心中的动机",
	"hill_difficulty": "拒绝捷径，在艰难中学习顺服",
	"palace_beautiful": "安息、团契与属灵军装",
	"valley_humiliation": "在控告与恐吓前站立在恩典中",
	"valley_shadow_death": "在黑暗中倚靠话语而非眼见",
	"vanity_fair": "拒绝虚荣交易，并作真实见证",
	"doubting_castle": "以应许反抗绝望，不把牢房当作家",
	"delectable_mountains": "接受牧人的警戒，重新望向天城",
	"enchanted_ground": "在舒适的困倦中保持警醒",
	"river_of_death": "在惧怕中交托，靠怜悯抵达彼岸",
	"celestial_city": "欢迎、成全，以及从始至终被恩典带领",
}

const CHAPTER_MECHANIC_ZH := {
	"city_of_destruction": "背着重担穿过熟悉的城，回应亲人与嘲笑者，领受传道者的呼召。",
	"wilderness_road": "与固执、易迁同行或对话，在前方微光中继续前行。",
	"slough_of_despond": "在泥潭中寻找应许石与安全落脚处，并接受援手。",
	"wicket_gate": "在箭矢与控告中叩门，让善意把你拉进门内。",
	"cross_and_tomb": "靠近十字架，让重担落下，并领受新衣与确据。",
	"interpreter_house": "进入不同房间，默想图景背后的属灵问题。",
	"hill_difficulty": "辨认捷径的代价，沿艰难山路抵达顶端。",
	"palace_beautiful": "休息、聆听守望者，并穿戴为山谷预备的军装。",
	"valley_humiliation": "以祷告、应许和信心回应亚玻伦的控告。",
	"valley_shadow_death": "在视线受限中跟随灯中话语，拒绝黑暗低语。",
	"vanity_fair": "拒绝市集交易，守住见证，并遇见盼望。",
	"doubting_castle": "搜寻应许之钥，在绝望巨人的压迫中打开牢门。",
	"delectable_mountains": "听牧人劝戒，透过望远镜观看天城。",
	"enchanted_ground": "抵抗睡意，借对话、祷告与盼望保持清醒。",
	"river_of_death": "牵住盼望，进入水中并走向彼岸。",
	"celestial_city": "走上发光的道路，穿过敞开的门，让旅程归于赞美。",
}

const CHAPTER_INTRO_ZH := {
	"city_of_destruction": [
		"你在黎明前醒来，书仍摊在手中，背上的重担连睡眠也不能减轻。",
		"这城称它为恐惧，但书页上的话给它命名为真实：审判将临，而你的心还没有预备好。",
		"你所爱的人请你留下，显得理性一些。悔改开始于你不再因房子熟悉，就假装它安全。"
	],
	"wilderness_road": [
		"城门在身后缩小，熟悉的声音却仍追着你，要求你回到旧日的安稳。",
		"固执嘲笑你的惧怕，易迁喜欢盼望的声音，却还不知道道路会有多深。",
		"你学习说真话：不是骄傲地争辩，也不是讨好人的心，而是把眼睛定在远方的光上。"
	],
	"slough_of_despond": [
		"地面开始下陷，重担把每一步都拉得更沉。",
		"绝望说这就是你真实的样子；应许却在泥中仍然发声。",
		"你不能靠自救离开这里。谦卑会伸手，恩典会抓住。"
	],
	"wicket_gate": [
		"窄门在前方，控告像箭一样催你退后。",
		"你没有资格夸口，却仍可以叩门，因为怜悯邀请有重担的人来。",
		"善意不是奖赏强者，而是把求怜悯的人拉进门内。"
	],
	"cross_and_tomb": [
		"山路尽头，十字架立在光中；你背负已久的重担开始颤动。",
		"这里不是你证明自己的地方，而是恩典替你回答罪疚的地方。",
		"空墓旁的新衣提醒你：你不再由旧名定义。"
	],
	"interpreter_house": [
		"门内安静而明亮，每个房间都像一面照见心的镜子。",
		"真理不只是给你方向，也训练你分辨自己为何走路。",
		"停下来观看，直到图景开始反问你的心。"
	],
	"hill_difficulty": [
		"山路陡峭，旁边的捷径显得更友善、更轻省。",
		"容易的路常用舒服开头，却用失落收尾。",
		"真实的道路需要喘息、忍耐和顺服，却不会欺骗你。"
	],
	"palace_beautiful": [
		"夜色降下，美宫的门为疲惫的旅人打开。",
		"安息不是离开争战，而是为下一段路重新预备。",
		"听守望者的话，穿戴军装，因为控告者正在山谷等候。"
	],
	"valley_humiliation": [
		"谷地低沉，旧主人的声音从阴影中走出。",
		"亚玻伦提起你的过去，仿佛恩典从未临到。",
		"你站立不是因为自己无罪，而是因为十字架已经替你回答。"
	],
	"valley_shadow_death": [
		"光变得稀薄，道路像被黑暗吞没。",
		"这里眼睛帮不上忙，低语却很会假装成真理。",
		"抓住话语的灯，继续走；黎明不因你看不见就消失。"
	],
	"vanity_fair": [
		"市集灯火耀眼，每个摊位都承诺更闪亮的自我。",
		"这里什么都可以买卖，连平安也被包装成掌声。",
		"作见证会有代价，但盼望也会在人群中醒来。"
	],
	"doubting_castle": [
		"牢房潮湿，绝望把记忆改写成判决。",
		"巨人的脚步提醒你：忘记应许时，心会把牢门当成终点。",
		"重新寻找那把钥匙；它也许一直在你胸前。"
	],
	"delectable_mountains": [
		"高山空气清明，牧人的声音使你从疲惫中抬头。",
		"警戒也是怜悯，因为错误的路常从好看的岔口开始。",
		"透过望远镜望向天城，让真实的终点重新校正你的脚步。"
	],
	"enchanted_ground": [
		"草地柔软，空气安静，困意像安慰一样靠近。",
		"危险不总是咆哮；有时它只是让你不再在意。",
		"继续说话，继续记念，继续渴慕那座城。"
	],
	"river_of_death": [
		"最后的水横在面前，没有桥，也没有可以掌控的道路。",
		"惧怕翻涌时，盼望提醒你：这不是被丢弃，而是最后的交托。",
		"踏入水中，靠怜悯抵达彼岸。"
	],
	"celestial_city": [
		"过河之后，道路像清晨本身一样发光，前方的门没有怀疑看守。",
		"重担、羞耻、惧怕、假名和困倦都留在身后，不能越过河来。",
		"你不是因自己刚强而抵达；你是被恩典一路带回家。进来吧，蒙爱的朝圣者。"
	],
}

# Full canonical pilgrimage route.
const CANONICAL_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
	"interpreter_house",
	"hill_difficulty",
	"palace_beautiful",
	"valley_humiliation",
	"valley_shadow_death",
	"vanity_fair",
	"doubting_castle",
	"delectable_mountains",
	"enchanted_ground",
	"river_of_death",
	"celestial_city",
]

const MVP_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
]

const VERTICAL_SLICE_ROUTE := [
	"city_of_destruction",
	"wilderness_road",
	"slough_of_despond",
	"wicket_gate",
	"cross_and_tomb",
	"interpreter_house",
	"hill_difficulty",
	"palace_beautiful",
	"valley_humiliation",
]

# The shipped build now plays the full canonical pilgrimage to the Celestial City.
var route: Array = CANONICAL_ROUTE
var _data_cache: Dictionary = {}
var _world_root: Node = null
var _current_scene_instance: Node = null
var current_chapter_id: String = ""


func _ready() -> void:
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(func(_loc): _data_cache.clear())


func set_world_root(node: Node) -> void:
	_world_root = node


func get_route() -> Array:
	return route


# --- Data loading ---
func load_chapter_data(chapter_id: String) -> Dictionary:
	if _data_cache.has(chapter_id):
		return _data_cache[chapter_id]
	var path := CHAPTER_DIR + chapter_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("ChapterManager: missing chapter data " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data := _localize_chapter_data(chapter_id, parsed)
		_data_cache[chapter_id] = data
		return data
	push_warning("ChapterManager: failed to parse " + path)
	return {}


func _localize_chapter_data(chapter_id: String, data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var title_zh := String(out.get("title_zh", CHAPTER_TITLE_ZH.get(chapter_id, "")))
	var title_en := String(out.get("title", chapter_id))
	out["title"] = LocaleManager.bilingual(title_zh, title_en) if not LocaleManager.is_zh() else (title_zh if title_zh != "" else LocaleManager.zh_or_mixed(title_en))
	var fallback_fields := {
		"subtitle": CHAPTER_SUBTITLE_ZH,
		"spiritual_theme": CHAPTER_THEME_ZH,
		"core_mechanic": CHAPTER_MECHANIC_ZH,
	}
	for field in ["subtitle", "spiritual_theme", "core_mechanic"]:
		var zh := String(out.get(field + "_zh", fallback_fields[field].get(chapter_id, "")))
		var en := String(out.get(field, ""))
		out[field] = LocaleManager.bilingual(zh, en) if not LocaleManager.is_zh() else (zh if zh != "" else LocaleManager.zh_or_mixed(en))
	if out.has("intro"):
		var intro: Array = out.get("intro", [])
		var intro_zh: Array = out.get("intro_zh", CHAPTER_INTRO_ZH.get(chapter_id, []))
		var localized: Array = []
		for i in range(intro.size()):
			var en_line := String(intro[i])
			var zh_line := String(intro_zh[i]) if i < intro_zh.size() else ""
			localized.append(LocaleManager.bilingual(zh_line, en_line) if not LocaleManager.is_zh() else (zh_line if zh_line != "" else LocaleManager.zh_or_mixed(en_line)))
		out["intro"] = localized
	return out


func get_current_chapter_data() -> Dictionary:
	return load_chapter_data(current_chapter_id)


# --- Route helpers ---
func get_chapter_index(chapter_id: String) -> int:
	return route.find(chapter_id)


func get_next_chapter_id(chapter_id: String) -> String:
	var data := load_chapter_data(chapter_id)
	if data.has("next_chapter_id"):
		return String(data["next_chapter_id"])
	var idx := get_chapter_index(chapter_id)
	if idx >= 0 and idx + 1 < route.size():
		return route[idx + 1]
	return ""


func get_previous_chapter_id(chapter_id: String) -> String:
	var idx := get_chapter_index(chapter_id)
	if idx > 0:
		return route[idx - 1]
	return ""


func can_enter_chapter(chapter_id: String) -> bool:
	var data := load_chapter_data(chapter_id)
	for flag in data.get("required_flags", []):
		if not GameState.has_flag(String(flag)):
			return false
	return true


# --- Lifecycle ---
func start_chapter(chapter_id: String) -> void:
	var data := load_chapter_data(chapter_id)
	if data.is_empty():
		push_error("ChapterManager: cannot start unknown chapter " + chapter_id)
		return
	current_chapter_id = chapter_id
	GameState.current_chapter_id = chapter_id
	GameState.current_scene_path = String(data.get("scene_path", ""))
	GameState.mark_chapter_visited(chapter_id)
	GameState.set_flag(String(data.get("id", chapter_id)) + "_started", true)
	apply_chapter_entry_effects(chapter_id)
	# Clean up stragglers: complete the quests of every EARLIER chapter in the
	# route, so the objective tracker always reflects the current chapter instead
	# of an old, partly-finished one (e.g. leave_city lingering into later chapters
	# when the player left without reading the book or facing Obstinate).
	var idx := get_chapter_index(chapter_id)
	for i in range(maxi(0, idx)):
		for pq in load_chapter_data(route[i]).get("quests", []):
			QuestManager.complete_quest(String(pq))
	# Start the chapter's quests.
	for q in data.get("quests", []):
		QuestManager.start_quest(String(q))
	load_chapter_scene(chapter_id)
	EventBus.chapter_started.emit(chapter_id)
	# Autosave on entry so "Continue" always resumes at the latest chapter.
	SaveManager.save_game("slot_1", false)


func apply_chapter_entry_effects(chapter_id: String) -> void:
	# Apply entry effects only once per chapter, so reloading or re-entering a
	# chapter does not stack them on top of the already-saved state.
	var guard := chapter_id + "_entry_applied"
	if GameState.has_flag(guard):
		return
	var data := load_chapter_data(chapter_id)
	var effects: Dictionary = data.get("entry_effects", {})
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	for k in (data.get("on_start_flags", {}) as Dictionary).keys():
		GameState.set_flag(String(k), data["on_start_flags"][k])
	GameState.set_flag(guard, true)


func apply_chapter_completion_effects(chapter_id: String) -> void:
	var data := load_chapter_data(chapter_id)
	var effects: Dictionary = data.get("completion_effects", {})
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	for k in (data.get("on_complete_flags", {}) as Dictionary).keys():
		GameState.set_flag(String(k), data["on_complete_flags"][k])


func evaluate_completion_conditions(chapter_id: String) -> bool:
	var data := load_chapter_data(chapter_id)
	var conditions: Array = data.get("completion_conditions", [])
	if conditions.is_empty():
		return true
	for cond in conditions:
		if String(cond.get("type", "flag")) == "flag":
			var key: String = String(cond.get("key", ""))
			var want: Variant = cond.get("value", true)
			if GameState.get_flag(key, null) != want:
				return false
	return true


func complete_chapter(chapter_id: String) -> void:
	apply_chapter_completion_effects(chapter_id)
	GameState.set_flag(chapter_id + "_completed", true)
	_request_completion_reflection(chapter_id)
	EventBus.chapter_completed.emit(chapter_id)


func _request_completion_reflection(chapter_id: String) -> void:
	var flag := "reflected_" + chapter_id
	if GameState.has_flag(flag):
		return
	var card := ScriptureMemory.get_chapter_card(chapter_id)
	if card.is_empty():
		return
	var data := load_chapter_data(chapter_id)
	var title := "本章复盘：" + String(data.get("title", CHAPTER_TITLE_ZH.get(chapter_id, chapter_id)))
	var body := PackedStringArray()
	body.append("[b]刚走过的路[/b]  %s" % String(data.get("subtitle", "")))
	body.append(ScriptureMemory.learning_body(card))
	body.append("[b]带进下一章[/b]  不是急着通关，而是把这节经文带进下一次选择。")
	EventBus.learning_moment_requested.emit({
		"title": title,
		"body": "\n\n".join(body),
		"flag_on_continue": flag,
		"effects_on_continue": {"watchfulness": 1, "hope": 1},
	})


func go_to_next_chapter() -> void:
	var next_id := get_next_chapter_id(current_chapter_id)
	complete_chapter(current_chapter_id)
	if next_id == "":
		# End of route: signal the game-complete flow.
		EventBus.toast("这段朝圣路已经完成。")
		return
	start_chapter(next_id)


func load_chapter_scene(chapter_id: String) -> void:
	if _world_root == null:
		push_error("ChapterManager: no world root set")
		return
	var data := load_chapter_data(chapter_id)
	var scene_path: String = String(data.get("scene_path", ""))
	# Free previous chapter.
	if is_instance_valid(_current_scene_instance):
		_current_scene_instance.queue_free()
		_current_scene_instance = null
	var instance: Node = null
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		if packed != null:
			instance = packed.instantiate()
	if instance == null:
		push_warning("ChapterManager: scene_path missing, using empty Node3D for " + chapter_id)
		instance = Node3D.new()
		instance.name = "EmptyChapter_" + chapter_id
	_current_scene_instance = instance
	_world_root.add_child(instance)
	EventBus.chapter_scene_loaded.emit(chapter_id)


func get_current_scene_instance() -> Node:
	return _current_scene_instance

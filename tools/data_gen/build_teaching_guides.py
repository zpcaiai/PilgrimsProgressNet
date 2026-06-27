"""Generate Sunday-school / catechism teaching guides for all 16 scenes.

Batch 7 · Skill 54 (主日学教学模式), mapped onto the Godot game. One JSON per
engine scene id in data/teaching_guides/<scene_id>.json. Bilingual (zh + en) so the
in-game TeachingGuidePanel can render in either locale. Keyed to the engine's actual
16 scenes (so wilderness_road has its own guide, and the folded scenes —
palace_beautiful=House Beautiful+Armory, valley_humiliation=Humility+Apollyon,
vanity_fair=Vanity Fair+Faithful's martyrdom — carry both themes).

Scripture references are standard, well-known mappings of Bunyan's allegory; kept
deliberately conservative for accuracy.

    python3 tools/data_gen/build_teaching_guides.py
    python3 tools/data_gen/build_teaching_guides.py --check   # validate only

Re-runnable / idempotent.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "data", "teaching_guides")
CHAPTERS = os.path.join(ROOT, "data", "chapters")

AUDIENCES = {"children", "youth", "seekers", "adult", "small_group"}


def ref(label_zh, label_en, reference_zh, reference_en, note_zh, note_en):
    return {"label_zh": label_zh, "label_en": label_en,
            "reference_zh": reference_zh, "reference_en": reference_en,
            "note_zh": note_zh, "note_en": note_en}


def q(qid, audience, zh, en):
    return {"id": qid, "audience": audience, "question_zh": zh, "question_en": en}


GUIDES = {
    "city_of_destruction": {
        "order": 1, "title_zh": "灭亡城", "title_en": "City of Destruction",
        "story_zh": "天路客读到自己的城将被审判，背着无法卸下的重担，在传福音者的指引下，不顾家人与顽固的拦阻，向着远处的光与窄门逃离。",
        "story_en": "The pilgrim reads that his city faces judgement. Burdened with a weight he cannot shed, and against the pull of family and Obstinate, he flees toward the distant light and the narrow gate, as Evangelist directs.",
        "theme_zh": "神的话唤醒人看见自己的罪与将来的审判；真正的觉醒会让人愿意离开熟悉却将亡的处境。",
        "theme_en": "God's word awakens a person to see sin and coming judgement; true awakening makes one willing to leave a familiar but doomed place.",
        "refs": [
            ref("审判临近", "Judgement is coming", "彼得后书 3:9-10", "2 Peter 3:9-10",
                "主不愿一人沉沦，乃愿人都悔改；主的日子要像贼一样来到。", "The Lord is patient, not willing that any perish; the Day of the Lord will come like a thief."),
            ref("逃离与不回头", "Flee and do not look back", "创世记 19:17", "Genesis 19:17",
                "逃命吧，不要回头看，免得被剿灭。", "Flee for your life; do not look back, lest you be swept away."),
            ref("我当怎样行", "What must I do", "使徒行传 2:37-38", "Acts 2:37-38",
                "众人觉得扎心，问当怎样行；彼得说要悔改。", "Cut to the heart, they ask what to do; Peter answers: repent."),
        ],
        "questions": [
            q("q1", "children", "天路客背上的重担是什么？为什么家里人不明白他？", "What is the burden on the pilgrim's back, and why don't his family understand him?"),
            q("q2", "youth", "顽固说『为了书上几句话就要离开？』你怎么回应这种声音？", "Obstinate says, 'leave it all for a few words in a book?' How would you answer that voice?"),
            q("q3", "adult", "什么样的『话』曾真正唤醒过你？觉醒之后你做了什么？", "What 'word' has truly awakened you, and what did you do once awakened?"),
        ],
        "teacher_notes_zh": ["重点不是恐吓审判，而是真理唤醒的恩典。", "强调觉醒带来的不是绝望，而是逃向生命的行动。"],
        "teacher_notes_en": ["The point is not to terrify with judgement but the grace of being awakened by truth.", "Stress that awakening leads not to despair but to a move toward life."],
        "reflection_zh": "写下：现在有什么『熟悉却不安全』的处境，是我一直不愿离开的？",
        "reflection_en": "Write down: what familiar-but-unsafe place have I been unwilling to leave?",
        "prayer_zh": "主啊，求你用你的话唤醒我，使我看清自己的光景，并给我起身上路的勇气。",
        "prayer_en": "Lord, awaken me by your word to see my true condition, and give me courage to rise and set out.",
    },
    "wilderness_road": {
        "order": 2, "title_zh": "旷野之路", "title_en": "The Wilderness Road",
        "story_zh": "刚出城的天路客走在荒路上，顽固已经折返，易迁还在身旁动摇，城里的声音不断招他回头；他要定睛在远处的光，不凭争辩或讨好继续前行。",
        "story_en": "Newly out of the city, the pilgrim walks a bleak road. Obstinate has turned back, Pliable wavers at his side, and the city's voices call him home; he must fix his eyes on the far light and press on without arguing or flattering.",
        "theme_zh": "起步的代价：分别为圣、不回头，定睛于前面的呼召而非身后的声音。",
        "theme_en": "The cost of beginning: separation, not looking back, eyes fixed on the call ahead rather than the voices behind.",
        "refs": [
            ref("手扶犁不回头", "Hand to the plough", "路加福音 9:62", "Luke 9:62",
                "手扶着犁向后看的，不配进神的国。", "No one who puts a hand to the plough and looks back is fit for the kingdom."),
            ref("计算代价", "Count the cost", "路加福音 14:28", "Luke 14:28",
                "盖楼之前先坐下算计花费。", "Before building, sit down and count the cost."),
            ref("忘记背后", "Forgetting what is behind", "腓立比书 3:13-14", "Philippians 3:13-14",
                "忘记背后，努力面前，向着标竿直跑。", "Forgetting what lies behind, straining forward toward the goal."),
        ],
        "questions": [
            q("q1", "children", "为什么易迁走着走着就想回家了？", "Why does Pliable start wanting to go home as they walk?"),
            q("q2", "youth", "『身后的声音』在你生活中可能是什么？怎样才能不回头？", "What are the 'voices behind' in your life, and how do you keep from looking back?"),
            q("q3", "adult", "你开始一段属灵旅程时，付过什么代价？哪些是你当时没料到的？", "What did beginning a spiritual journey cost you—what costs surprised you?"),
        ],
        "teacher_notes_zh": ["这是过渡章节，重点在『坚定起步』而非新教义。", "区分对顽固的回应（不争辩）与对易迁的扶持（不讨好）。"],
        "teacher_notes_en": ["A transitional chapter—focus on resolve to begin, not new doctrine.", "Distinguish answering Obstinate (no arguing) from steadying Pliable (no flattery)."],
        "reflection_zh": "写下：我前面那道『光』是什么？今天我可以为它放下哪一样身后之物？",
        "reflection_en": "Write down: what is the 'light' ahead for me, and what one thing behind can I set down for it today?",
        "prayer_zh": "主啊，求你坚固我刚起步的脚，使我定睛于你的呼召，不被身后的声音夺回。",
        "prayer_en": "Lord, steady my newly-started feet; fix my eyes on your call, and let no voice behind draw me back.",
    },
    "slough_of_despond": {
        "order": 3, "title_zh": "沮丧泥潭", "title_en": "Slough of Despond",
        "story_zh": "天路客陷入沮丧的泥潭，重担越重，越往下沉；易迁灰心折返，唯有谦卑呼求的人被『帮助』拉上岸，踏着应许之石走向窄门。",
        "story_en": "The pilgrim sinks in the mire of despondency; the heavier the burden, the deeper he sinks. Pliable despairs and turns back, but the one who humbly cries out is pulled up by Help and finds the stones of promise toward the gate.",
        "theme_zh": "初信的软弱与罪疚会使人下沉；出路不是自我挣扎，而是谦卑呼求与领受帮助。",
        "theme_en": "Early weakness and guilt drag a believer down; the way out is not self-struggle but a humble cry and receiving help.",
        "refs": [
            ref("从泥潭被拉起", "Lifted from the mire", "诗篇 40:1-3", "Psalm 40:1-3",
                "他从祸坑里、淤泥中把我拉上来，使我脚立在磐石上。", "He drew me up from the miry bog and set my feet upon a rock."),
            ref("从深处呼求", "Out of the depths", "诗篇 130:1-2", "Psalm 130:1-2",
                "耶和华啊，我从深处向你求告。", "Out of the depths I cry to you, O LORD."),
            ref("呼求必蒙应允", "Call and be heard", "诗篇 50:15", "Psalm 50:15",
                "在患难之日求告我，我必搭救你。", "Call upon me in the day of trouble; I will deliver you."),
        ],
        "questions": [
            q("q1", "children", "天路客越用力越往下沉，是谁来把他拉上来？", "The harder he tries the deeper he sinks—who comes to pull him out?"),
            q("q2", "youth", "为什么易迁离开了，天路客却没有？两人有什么不同？", "Why does Pliable leave but the pilgrim does not—what is different about them?"),
            q("q3", "adult", "你有没有试过靠自己爬出『泥潭』？什么时候你才肯呼求帮助？", "Have you tried to climb out of a 'slough' alone—when did you finally cry for help?"),
        ],
        "teacher_notes_zh": ["泥潭不是惩罚，而是罪疚与灰心的真实感受。", "强调『呼求帮助』本身就是初步的悔改与信心。"],
        "teacher_notes_en": ["The slough is not punishment but the felt reality of guilt and discouragement.", "Stress that crying for help is itself an early act of repentance and faith."],
        "reflection_zh": "写下：现在有什么让我越挣扎越下沉？我愿意把它变成一句呼求吗？",
        "reflection_en": "Write down: what makes me sink the harder I struggle—will I turn it into a single cry for help?",
        "prayer_zh": "主啊，我从深处向你呼求；我不能自己爬出泥潭，求你伸手拉我上来，使我站在磐石上。",
        "prayer_en": "Lord, out of the depths I cry; I cannot climb out alone—reach down, lift me, and set my feet on the rock.",
    },
    "wicket_gate": {
        "order": 4, "title_zh": "窄门", "title_en": "The Wicket Gate",
        "story_zh": "天路客顶着控告的箭，来到窄门前叩门；善意把他拉进门内，使他进入唯一正路。",
        "story_en": "Pressing through arrows of accusation, the pilgrim knocks at the narrow gate; Goodwill draws him through into the one true way.",
        "theme_zh": "信心是叩门与求问；恩典是为求问的人开门。进窄门是进入基督这唯一的门。",
        "theme_en": "Faith asks and knocks; grace opens to those who ask. To enter the narrow gate is to enter Christ, the one door.",
        "refs": [
            ref("叩门就开", "Knock and it opens", "马太福音 7:7-8", "Matthew 7:7-8",
                "叩门，就给你们开门；凡叩门的，就给他开门。", "Knock and it will be opened to you; everyone who knocks, the door is opened."),
            ref("进窄门", "Enter the narrow gate", "马太福音 7:13-14", "Matthew 7:13-14",
                "你们要进窄门……引到永生的路是窄的。", "Enter by the narrow gate; the way that leads to life is narrow."),
            ref("我就是门", "I am the door", "约翰福音 10:9", "John 10:9",
                "我就是门；凡从我进来的，必然得救。", "I am the door. If anyone enters by me, he will be saved."),
        ],
        "questions": [
            q("q1", "children", "门很窄，可是是关着还是开着的？要先做什么？", "The gate is narrow—is it shut or open, and what must you do first?"),
            q("q2", "youth", "什么样的『箭』会让人不敢上前叩门？", "What kind of 'arrows' make a person afraid to step up and knock?"),
            q("q3", "adult", "『叩门』在你信心生活中具体是什么样子？你还在为什么叩门？", "What does 'knocking' look like in your life of faith—what are you still knocking for?"),
        ],
        "teacher_notes_zh": ["窄不等于关；门是为叩门的人开的。", "把窄门指向基督自己（约10:9），不要停在道德努力上。"],
        "teacher_notes_en": ["Narrow does not mean shut; the gate opens to those who knock.", "Point the narrow gate to Christ himself (Jn 10:9), not mere moral effort."],
        "reflection_zh": "写下：有什么是我一直在门外徘徊、却不敢叩的？",
        "reflection_en": "Write down: what have I been lingering outside the door over, not daring to knock?",
        "prayer_zh": "主啊，你是那门；我叩门，求你为我开，领我进入唯一的正路。",
        "prayer_en": "Lord, you are the door; I knock—open to me and bring me into the one true way.",
    },
    "cross_and_tomb": {
        "order": 5, "title_zh": "十架山", "title_en": "Calvary — Cross and Tomb",
        "story_zh": "天路客越爬重担越沉，直到来到十字架前；重担的带子断开，滚入空坟。他得着确据的书卷、印记与新衣，从此身份是『蒙赦免的人』。",
        "story_en": "The higher he climbs the heavier the burden, until he comes to the Cross; the strap breaks and the burden rolls into the empty tomb. He receives a scroll of assurance, a seal, and a new garment—his identity now 'forgiven'.",
        "theme_zh": "人不能靠自己除去罪的重担，唯有在基督十字架前得赦免、称义与确据。重担脱落是恩典临到，不是玩家成就。",
        "theme_en": "No one can remove the burden of sin by himself; only at Christ's cross is there pardon, justification, and assurance. The burden falls as grace arriving, not as the player's achievement.",
        "refs": [
            ref("他担当我们的罪", "He bore our sins", "以赛亚书 53:5-6", "Isaiah 53:5-6",
                "他为我们的过犯受害……耶和华使我们众人的罪孽都归在他身上。", "He was pierced for our transgressions; the LORD laid on him the iniquity of us all."),
            ref("到我这里得安息", "Come to me and rest", "马太福音 11:28", "Matthew 11:28",
                "凡劳苦担重担的人，可以到我这里来，我就使你们得安息。", "Come to me, all who labour and are heavy laden, and I will give you rest."),
            ref("因信称义得平安", "Justified, at peace", "罗马书 5:1", "Romans 5:1",
                "我们既因信称义，就借着主耶稣基督得与神相和。", "Since we have been justified by faith, we have peace with God through our Lord Jesus Christ."),
        ],
        "questions": [
            q("q1", "children", "重担是在哪里掉下来的？是天路客自己解开的吗？", "Where does the burden fall off—does the pilgrim untie it himself?"),
            q("q2", "youth", "为什么重担不是在讲解者之家（看见真理）脱落，而是在十字架前？", "Why does the burden fall not at the Interpreter's House (seeing truth) but at the Cross?"),
            q("q3", "adult", "你是否曾想靠努力除去罪疚或惧怕？知道真理与被基督释放有什么不同？", "Have you tried to remove guilt or fear by effort? What is the difference between knowing truth and being set free by Christ?"),
        ],
        "teacher_notes_zh": ["不要把这一章讲成心理释放，要指向基督的代赎。", "强调赦免是领受，不是赚取；重担脱落后身份改变（蒙赦免）。"],
        "teacher_notes_en": ["Don't reduce this to psychological release—point to Christ's atonement.", "Stress pardon is received, not earned; after the burden falls, identity changes (forgiven)."],
        "reflection_zh": "写下：我现在最像重担的东西是什么？我是否愿意把它带到十字架前？",
        "reflection_en": "Write down: what most feels like a burden to me now—will I bring it to the Cross?",
        "prayer_zh": "主啊，我不能自己除去罪与惧怕的重担，求你带我到十字架前，得着赦免与安息。",
        "prayer_en": "Lord, I cannot remove the burden of sin and fear myself—bring me to the Cross for pardon and rest.",
    },
    "interpreter_house": {
        "order": 6, "title_zh": "讲解者之家", "title_en": "Interpreter's House",
        "story_zh": "讲解者用一间间象征的房间——画像、尘土、火焰、宫殿、铁笼、审判之梦——教导天路客分辨属灵的真实，预备他的眼睛与心。",
        "story_en": "The Interpreter teaches the pilgrim through symbolic rooms—a portrait, dust, hidden fire, a palace, an iron cage, a dream of judgement—training his eyes and heart to discern spiritual reality.",
        "theme_zh": "属灵分辨：求神开我们的眼，看出表象底下的真相，并被圣灵引导进入真理。",
        "theme_en": "Spiritual discernment: asking God to open our eyes to the truth beneath appearances, led into truth by the Spirit.",
        "refs": [
            ref("开我的眼睛", "Open my eyes", "诗篇 119:18", "Psalm 119:18",
                "求你开我的眼睛，使我看出你律法中的奇妙。", "Open my eyes, that I may behold wondrous things out of your law."),
            ref("圣灵引导进真理", "The Spirit guides", "约翰福音 16:13", "John 16:13",
                "真理的圣灵来了，要引导你们进入一切真理。", "When the Spirit of truth comes, he will guide you into all truth."),
            ref("属灵的事属灵分辨", "Spiritually discerned", "哥林多前书 2:14", "1 Corinthians 2:14",
                "属血气的人不领会神圣灵的事……惟有属灵的人才能看透。", "The natural person does not accept the things of the Spirit; they are spiritually discerned."),
        ],
        "questions": [
            q("q1", "children", "讲解者之家里哪一个房间让你印象最深？为什么？", "Which room in the Interpreter's House struck you most, and why?"),
            q("q2", "youth", "火焰房间里，仇敌泼水却浇不灭火，因为有人在墙后浇油——这是什么意思？", "In the fire room, the enemy throws water but the fire won't die because someone pours oil behind the wall—what does this mean?"),
            q("q3", "adult", "你最近一次『看错』属灵的事，是什么让你后来看清的？", "When did you last misread something spiritual—what later helped you see clearly?"),
        ],
        "teacher_notes_zh": ["铁笼之人是警戒，不要轻看恩典直到心硬。", "讲解者最后指向十字架——分辨是为了走向基督。"],
        "teacher_notes_en": ["The man in the iron cage is a warning against despising grace until the heart hardens.", "The Interpreter finally points to the Cross—discernment is for moving toward Christ."],
        "reflection_zh": "写下：有什么属灵真相，我『知道』却还没有『看见』？",
        "reflection_en": "Write down: what spiritual truth do I 'know' but have not yet 'seen'?",
        "prayer_zh": "主啊，求你开我的眼睛，借着你的灵引导我进入真理，使我能分辨真假。",
        "prayer_en": "Lord, open my eyes; by your Spirit guide me into truth, that I may discern the true from the false.",
    },
    "hill_difficulty": {
        "order": 7, "title_zh": "艰难山", "title_en": "Hill Difficulty",
        "story_zh": "三条路在山脚分岔：陡峭的正路，以及看似轻松的『危险』『毁灭』旁路。天路客选择艰难正路，在凉亭警醒不沉睡，凭信走过被锁的狮子，抵达美宫。",
        "story_en": "Three paths fork at the hill's foot: the steep true way, and the easy-looking bypaths Danger and Destruction. The pilgrim takes the hard road, stays watchful at the arbor, passes the chained lions by faith, and reaches the Palace.",
        "theme_zh": "成圣的道路是窄而难的；旁路虽轻松却通向危险。忍耐、警醒、拒绝捷径，是门徒的功课。",
        "theme_en": "The road of sanctification is narrow and hard; bypaths look easy but lead to danger. Endurance, watchfulness, and refusing shortcuts are the disciple's lessons.",
        "refs": [
            ref("经历艰难进神国", "Through tribulation", "使徒行传 14:22", "Acts 14:22",
                "我们进入神的国，必须经历许多艰难。", "Through many tribulations we must enter the kingdom of God."),
            ref("引到生命的路是窄的", "The hard way to life", "马太福音 7:14", "Matthew 7:14",
                "引到永生，那门是窄的，路是小的，找着的人也少。", "The gate is narrow and the way is hard that leads to life, and those who find it are few."),
            ref("存心忍耐奔那路程", "Run with endurance", "希伯来书 12:1", "Hebrews 12:1",
                "放下各样的重担……存心忍耐，奔那摆在我们前头的路程。", "Lay aside every weight, and run with endurance the race set before us."),
        ],
        "questions": [
            q("q1", "children", "两条旁路看起来更好走，为什么走它们反而危险？", "The two bypaths look easier—why is taking them actually dangerous?"),
            q("q2", "youth", "在凉亭睡着会丢掉确据书卷。属灵上『在凉亭沉睡』是什么样子？", "Sleeping at the arbor loses the scroll. What does 'sleeping at the arbor' look like spiritually?"),
            q("q3", "adult", "你最近一次想抄『轻松的捷径』是什么？结果如何？", "When did you last want an easy shortcut—how did it turn out?"),
        ],
        "teacher_notes_zh": ["旁路不是立刻毁灭，而是渐渐失去警醒——这正是危险所在。", "狮子是被锁的：很多惧怕在凭信走近时显出其界限。"],
        "teacher_notes_en": ["Bypaths don't destroy at once but slowly erode watchfulness—that is the danger.", "The lions are chained: many fears show their limits when approached by faith."],
        "reflection_zh": "写下：我现在面前的『陡坡』是什么？哪条『旁路』在向我招手？",
        "reflection_en": "Write down: what is the steep climb before me, and which bypath is beckoning?",
        "prayer_zh": "主啊，求你给我忍耐走窄路，警醒不沉睡，不为图轻省而偏行旁路。",
        "prayer_en": "Lord, give me endurance for the narrow road, watchfulness against sleep, and grace not to turn aside for ease.",
    },
    "palace_beautiful": {
        "order": 8, "title_zh": "美宫与神圣军装", "title_en": "House Beautiful & the Armour",
        "story_zh": "守望者在门口察验天路客；审慎、谨慎、敬虔、仁爱接待他、考问他、与他团契安息。临行前，他在军装厅领受神所赐的全副军装，预备下到降卑谷。",
        "story_en": "Watchful examines the pilgrim at the gate; Discretion, Prudence, Piety, and Charity welcome, question, and rest with him in fellowship. Before he leaves, he takes up the whole armour of God in the armoury, preparing to descend into the Valley of Humiliation.",
        "theme_zh": "教会的团契、接待与省察是成长所必需；安息之后是装备——穿上属灵军装，预备争战，而非夸耀。",
        "theme_en": "The fellowship, hospitality, and examination of the church are vital to growth; after rest comes equipping—putting on spiritual armour to prepare for battle, not for boasting.",
        "refs": [
            ref("彼此相顾、不可停止聚会", "Do not neglect to meet", "希伯来书 10:24-25", "Hebrews 10:24-25",
                "彼此相顾，激发爱心，勉励行善，不可停止聚会。", "Stir up one another to love and good works, not neglecting to meet together."),
            ref("一味地款待客旅", "Practice hospitality", "罗马书 12:13", "Romans 12:13",
                "圣徒缺乏要帮补，客要一味地款待。", "Contribute to the needs of the saints and seek to show hospitality."),
            ref("穿戴神的全副军装", "The whole armour of God", "以弗所书 6:11-13", "Ephesians 6:11-13",
                "要穿戴神所赐的全副军装，就能抵挡魔鬼的诡计。", "Put on the whole armour of God, that you may stand against the schemes of the devil."),
        ],
        "questions": [
            q("q1", "children", "美宫里有哪些人接待天路客？他们给了他什么？", "Who welcomes the pilgrim in the Palace, and what do they give him?"),
            q("q2", "youth", "守望者在门口察验他『你是谁？』——为什么教会要彼此察验？", "Watchful examines him at the gate, 'who are you?'—why does the church examine one another?"),
            q("q3", "adult", "保罗列出的六件军装中，你现在最需要操练哪一件？为什么？", "Of Paul's six pieces of armour, which do you most need to train in now, and why?"),
        ],
        "teacher_notes_zh": ["夸耀（boast）是这里的陷阱：安息之后的骄傲会拆毁人。", "军装是为站立和谦卑争战，不是为炫耀属灵成就。"],
        "teacher_notes_en": ["Boasting is the snare here: pride after rest undoes a person.", "The armour is for standing and humble battle, not parading spiritual achievement."],
        "reflection_zh": "写下：我有真实的属灵团契吗？我愿意被弟兄姊妹『察验』吗？",
        "reflection_en": "Write down: do I have real spiritual fellowship—am I willing to be examined by others?",
        "prayer_zh": "主啊，谢谢你赐下团契与安息；求你给我穿上全副军装的心，谦卑预备前面的争战。",
        "prayer_en": "Lord, thank you for fellowship and rest; give me a heart to put on the whole armour and humbly prepare for the battle ahead.",
    },
    "valley_humiliation": {
        "order": 9, "title_zh": "降卑谷与亚玻伦", "title_en": "Valley of Humiliation & Apollyon",
        "story_zh": "穿上军装后，路向下进入降卑谷——军装是为谦卑，不是为骄傲。旧主亚玻伦拦路，控告天路客曾属于他，用火箭与控告攻击；天路客用信德的盾牌与圣灵的宝剑站立，得胜后谦卑感恩，而非夸口。",
        "story_en": "After the armour, the road descends into Humiliation—armour is for lowliness, not pride. Apollyon, the old master, blocks the way, accusing the pilgrim of once belonging to him and assaulting him with fiery darts and accusation; the pilgrim stands by the shield of faith and the sword of the Spirit, and after victory gives humble thanks rather than boasting.",
        "theme_zh": "属灵争战的真相：仇敌靠控告与恐吓，信徒靠基督的救赎、应许与神的话得胜；得胜之后要谦卑感恩。",
        "theme_en": "The truth of spiritual warfare: the enemy works by accusation and intimidation; the believer overcomes by Christ's redemption, the promises, and God's word—and after victory gives humble thanks.",
        "refs": [
            ref("因羔羊的血得胜", "Overcame by the blood", "启示录 12:11", "Revelation 12:11",
                "弟兄胜过它，是因羔羊的血和自己所见证的道。", "They overcame him by the blood of the Lamb and the word of their testimony."),
            ref("争战的对象", "Our struggle", "以弗所书 6:12", "Ephesians 6:12",
                "我们并不是与属血气的争战，乃是与那些执政的、掌权的……争战。", "We do not wrestle against flesh and blood, but against the rulers and authorities."),
            ref("顺服神，抵挡魔鬼", "Resist the devil", "雅各书 4:7", "James 4:7",
                "你们要顺服神，务要抵挡魔鬼，魔鬼就必离开你们逃跑了。", "Submit to God. Resist the devil, and he will flee from you."),
        ],
        "questions": [
            q("q1", "children", "亚玻伦用什么攻击天路客？天路客用什么挡住它？", "What does Apollyon attack with, and what does the pilgrim use to block it?"),
            q("q2", "youth", "亚玻伦提起天路客过去的失败来控告他。我们该怎样回应这种控告？", "Apollyon recalls the pilgrim's past failures to accuse him—how should we answer such accusation?"),
            q("q3", "adult", "为什么得胜后必须『谦卑感恩』而不是『夸口』？骄傲会如何反噬？", "Why must victory be met with humble thanks, not boasting—how does pride backfire?"),
        ],
        "teacher_notes_zh": ["控告常用『真实的过去』；答案不是否认，而是基督已经赦免（确据书卷）。", "失败不等于结局：被控告打倒不是游戏结束，可以悔改恢复。"],
        "teacher_notes_en": ["Accusation often uses a 'real past'; the answer is not denial but that Christ has forgiven (the scroll of assurance).", "Failure is not the end: being downed by accusation is not game over—one can repent and recover."],
        "reflection_zh": "写下：仇敌最常用我过去的哪一件事来控告我？基督的赦免如何回答它？",
        "reflection_en": "Write down: which past event does the accuser most use against me—how does Christ's pardon answer it?",
        "prayer_zh": "主啊，当控告临到，求你叫我靠你的宝血与你的话站立；得胜时给我谦卑感恩的心。",
        "prayer_en": "Lord, when accusation comes, let me stand by your blood and your word; in victory give me a humble, thankful heart.",
    },
    "valley_shadow_death": {
        "order": 10, "title_zh": "死荫谷", "title_en": "Valley of the Shadow of Death",
        "story_zh": "亚玻伦之后，天路客独自走进漆黑的死荫谷：极窄的路，左边深坑、右边泥沼，黑暗中满是低语。他凭祷告的微光看清下一步，不偏左右，直到黎明破晓。",
        "story_en": "After Apollyon, the pilgrim walks alone into the pitch-black valley: an extremely narrow path with a ditch on the left and a quag on the right, the dark full of whispers. By the faint light of prayer he sees the next step, swerving neither way, until dawn breaks.",
        "theme_zh": "黑暗中的持守：当感觉不到神同在时，仍凭祷告与神的话一步步前行；信心是凭信不凭眼见。",
        "theme_en": "Holding fast in the dark: when God's presence cannot be felt, still moving step by step by prayer and the word; faith walks by faith, not by sight.",
        "refs": [
            ref("行过死荫幽谷不怕", "Through the valley", "诗篇 23:4", "Psalm 23:4",
                "我虽然行过死荫的幽谷，也不怕遭害，因为你与我同在。", "Even though I walk through the valley of the shadow of death, I will fear no evil, for you are with me."),
            ref("你的话是脚前的灯", "A lamp to my feet", "诗篇 119:105", "Psalm 119:105",
                "你的话是我脚前的灯，是我路上的光。", "Your word is a lamp to my feet and a light to my path."),
            ref("凭信心不凭眼见", "By faith, not sight", "哥林多后书 5:7", "2 Corinthians 5:7",
                "我们行事为人是凭着信心，不是凭着眼见。", "We walk by faith, not by sight."),
        ],
        "questions": [
            q("q1", "children", "天路客在黑暗里怎么知道往哪里走？", "How does the pilgrim know which way to go in the dark?"),
            q("q2", "youth", "黑暗中的『低语』说『没有人听见你的祷告』。你怎么分辨这是谎言？", "The whispers say 'no one hears your prayer'. How do you tell this is a lie?"),
            q("q3", "adult", "当你感觉不到神同在时，什么帮助你继续走下去？", "When you cannot feel God's presence, what helps you keep going?"),
        ],
        "teacher_notes_zh": ["死荫谷不是战斗，而是『持守』——重点在祷告与神的话。", "偏左（深坑）与偏右（泥沼）都危险：真理常在两端错误之间的窄路上。"],
        "teacher_notes_en": ["The valley is not a fight but a holding fast—focus on prayer and the word.", "Both left (ditch) and right (quag) are dangerous: truth often runs the narrow path between two errors."],
        "reflection_zh": "写下：我现在的『黑暗』是什么？我能为下一步祷告，而不是为整条路焦虑吗？",
        "reflection_en": "Write down: what is my present 'darkness'—can I pray for the next step rather than fret over the whole road?",
        "prayer_zh": "主啊，我虽行过幽谷也不怕，因你与我同在；求你用你的话作我脚前的灯，照亮我的下一步。",
        "prayer_en": "Lord, though I walk through the valley I will not fear, for you are with me; let your word be a lamp to my feet for the next step.",
    },
    "vanity_fair": {
        "order": 11, "title_zh": "虚华市与忠信殉道", "title_en": "Vanity Fair & Faithful's Martyrdom",
        "story_zh": "忠信在城门口与天路客会合，同进虚华市——名声、财富、安逸、宗教表演样样兜售，唯独不卖真理。他们拒绝货物、公开作见证，因而被捕；忠信受审殉道，盼望却因这见证被点燃，接续同行。",
        "story_en": "Faithful meets the pilgrim at the gate, and together they enter Vanity Fair—where fame, wealth, comfort, and religious show are all for sale, but never truth. They refuse the wares and bear public witness, and so are arrested; Faithful is tried and martyred, but Hopeful, set ablaze by the witness, joins to walk on.",
        "theme_zh": "不要爱世界；分辨假光，付代价作见证。忠心至死的见证不是失败，而是恩典的接续。",
        "theme_en": "Do not love the world; discern the false light, and bear costly witness. Faithfulness unto death is not failure but the passing-on of grace.",
        "refs": [
            ref("不要爱世界", "Do not love the world", "约翰一书 2:15-17", "1 John 2:15-17",
                "不要爱世界……这世界和其上的情欲都要过去，唯独遵行神旨意的永远长存。", "Do not love the world; the world is passing away, but whoever does the will of God abides forever."),
            ref("买真理，不可卖", "Buy truth, do not sell", "箴言 23:23", "Proverbs 23:23",
                "你当买真理，就是智慧、训诲和聪明，也都不可卖。", "Buy truth, and do not sell it; buy wisdom, instruction, and understanding."),
            ref("至死忠心得冠冕", "Faithful unto death", "启示录 2:10", "Revelation 2:10",
                "你务要至死忠心，我就赐给你那生命的冠冕。", "Be faithful unto death, and I will give you the crown of life."),
        ],
        "questions": [
            q("q1", "children", "虚华市什么都卖，就是不卖什么？", "Vanity Fair sells everything—except what?"),
            q("q2", "youth", "天路客和忠信说『我们买真理』。在你的学校或网络上，什么是『虚华市的货物』？", "They say 'we buy the truth'. At your school or online, what are 'the wares of Vanity Fair'?"),
            q("q3", "adult", "忠信殉道，盼望却因此加入。为什么说见证的『代价』也是它的『能力』？", "Faithful is martyred, yet Hopeful joins because of it. Why is the cost of witness also its power?"),
        ],
        "teacher_notes_zh": ["避免把世界简单等同于『娱乐』；虚华市也卖宗教表演与成功学。", "处理殉道时要把悲伤导向盼望（盼望的加入），不要停在惨烈上。"],
        "teacher_notes_en": ["Don't reduce 'the world' to entertainment; Vanity Fair also sells religious show and success-worship.", "Handle martyrdom by turning sorrow toward hope (Hopeful joining), not dwelling on horror."],
        "reflection_zh": "写下：有什么『发光的东西』正在向我要价？它真来自真光吗？",
        "reflection_en": "Write down: what 'shining thing' is asking a price of me—does it really come from the true light?",
        "prayer_zh": "主啊，求你给我分辨假光的眼，和付代价作见证的勇气；叫我爱你过于爱世界。",
        "prayer_en": "Lord, give me eyes to discern false light and courage for costly witness; let me love you more than the world.",
    },
    "doubting_castle": {
        "order": 12, "title_zh": "疑惑堡", "title_en": "Doubting Castle",
        "story_zh": "疲乏的天路客与盼望偏离正路，走进看似轻松的小路，被绝望巨人掳进疑惑堡。牢里绝望日增、黑念控告；直到盼望的鼓励使他想起怀中『应许之钥』，开门逃出，并为后人留下警戒。",
        "story_en": "Weary, the pilgrim and Hopeful stray onto an easier-looking path and are seized by Giant Despair into Doubting Castle. In the cell despair mounts and dark thoughts accuse, until Hopeful's encouragement makes him remember the Key of Promise in his own breast; he unlocks the door, escapes, and leaves a warning for those who follow.",
        "theme_zh": "即使走过十架、军装、得胜，疲乏的信徒仍可能因走捷径落入疑惑与绝望；出路是想起神的应许，并彼此扶持。",
        "theme_en": "Even after the Cross, armour, and victory, a weary believer can fall into doubt and despair by a shortcut; the way out is remembering God's promises and mutual encouragement.",
        "refs": [
            ref("绝望中神拯救", "Delivered from despair", "哥林多后书 1:8-10", "2 Corinthians 1:8-10",
                "我们……甚至连活命的指望都绝了……叫我们不靠自己，只靠叫死人复活的神。", "We despaired of life itself, that we might rely not on ourselves but on God who raises the dead."),
            ref("我心仍有指望", "Therefore I have hope", "耶利米哀歌 3:21-23", "Lamentations 3:21-23",
                "我想起这事，心里就有指望：耶和华的慈爱永不断绝……每早晨都是新的。", "This I recall, and therefore I have hope: the LORD's mercies never cease; they are new every morning."),
            ref("又宝贵又极大的应许", "Precious promises", "彼得后书 1:4", "2 Peter 1:4",
                "他已将又宝贵又极大的应许赐给我们。", "He has granted to us his precious and very great promises."),
        ],
        "questions": [
            q("q1", "children", "天路客被关在牢里，最后是什么钥匙救了他？", "Locked in the cell, what key finally frees the pilgrim?"),
            q("q2", "youth", "『应许之钥』一直在他怀里，他却忘了。绝望怎样让人忘记自己已有的？", "The key was in his breast all along, yet he forgot. How does despair make us forget what we already have?"),
            q("q3", "adult", "盼望的『陪伴与提醒』为什么常是走出绝望的关键？", "Why is Hopeful's company and reminding so often the key to leaving despair?"),
        ],
        "teacher_notes_zh": ["绝望会『编辑真相』——把暂时说成永远，把失败说成结局。", "钥匙是『应许』：恢复常常是想起神已经说过的话，而非新的经历。"],
        "teacher_notes_en": ["Despair 'edits the truth'—calling the temporary permanent, calling failure the end.", "The key is the Promise: recovery is often remembering what God has already said, not a new experience."],
        "reflection_zh": "写下：我现在的绝望把什么『暂时』说成了『永远』？哪一句应许能开这扇门？",
        "reflection_en": "Write down: what 'temporary' is my despair calling 'permanent'—which promise can open this door?",
        "prayer_zh": "主啊，当我被疑惑囚禁，求你叫我想起你的应许，借着同行者的提醒重得盼望，逃出绝望。",
        "prayer_en": "Lord, when doubt imprisons me, make me remember your promises, regain hope through a companion's reminder, and escape despair.",
    },
    "delectable_mountains": {
        "order": 13, "title_zh": "可喜山", "title_en": "Delectable Mountains",
        "story_zh": "出了疑惑堡，天路客与盼望来到可喜山，受四位牧人——知识、经历、警醒、诚实——的牧养。他们解释他为何走偏，透过望远镜让他望见天城，赐他地图，并警戒前面的魔睡地。",
        "story_en": "Out of the castle, the pilgrim and Hopeful reach the Delectable Mountains and are shepherded by Knowledge, Experience, Watchful, and Sincere. They explain why he strayed, show him the Celestial City through the glass, give him a map, and warn of the Enchanted Ground ahead.",
        "theme_zh": "牧养的恢复：跌倒之后，神借牧者重建眼界与盼望，赐下方向与警戒，使人重新定睛于天城。",
        "theme_en": "Pastoral restoration: after a fall, God rebuilds vision and hope through shepherds, giving direction and warning, refixing the eyes on the City.",
        "refs": [
            ref("耶和华是我的牧者", "The LORD my shepherd", "诗篇 23:1-3", "Psalm 23:1-3",
                "耶和华是我的牧者……他使我的灵魂苏醒，引导我走义路。", "The LORD is my shepherd… he restores my soul; he leads me in paths of righteousness."),
            ref("听从引导你们的", "Obey your leaders", "希伯来书 13:17", "Hebrews 13:17",
                "你们要依从那些引导你们的，因他们为你们的灵魂时刻警醒。", "Obey your leaders, for they keep watch over your souls."),
            ref("定睛望那城", "Looking to the city", "希伯来书 11:16", "Hebrews 11:16",
                "他们羡慕一个更美的家乡……神已经给他们预备了一座城。", "They desire a better country; God has prepared for them a city."),
        ],
        "questions": [
            q("q1", "children", "牧人让天路客用望远镜看见了什么？", "What do the shepherds let the pilgrim see through the glass?"),
            q("q2", "youth", "诚实牧人教他『诚实承认自己的软弱，不要假装刚强』——这为什么重要？", "Sincere teaches him to honestly admit weakness, not feign strength—why does this matter?"),
            q("q3", "adult", "在你属灵跌倒后，是谁（哪些『牧人』）帮助你重新望见盼望？", "After a spiritual fall, who (which 'shepherds') helped you see hope again?"),
        ],
        "teacher_notes_zh": ["可喜山是恢复站，不是终点：眺望天城是为了走完前面的路。", "牧养包括安慰，也包括警戒（魔睡地）——两者都是爱。"],
        "teacher_notes_en": ["The mountains are a recovery station, not the goal: the view of the City is for finishing the road.", "Shepherding includes both comfort and warning (the Enchanted Ground)—both are love."],
        "reflection_zh": "写下：我上一次清楚『望见天城』是什么时候？什么模糊了那个眼界？",
        "reflection_en": "Write down: when did I last clearly 'see the City'—what blurred that view?",
        "prayer_zh": "主啊，我的牧者，求你使我的灵魂苏醒，重立我的盼望，并赐我谦卑领受警戒的心。",
        "prayer_en": "Lord my shepherd, restore my soul, renew my hope, and give me a humble heart to receive warning.",
    },
    "enchanted_ground": {
        "order": 14, "title_zh": "魔睡地", "title_en": "The Enchanted Ground",
        "story_zh": "前面是美丽却催眠的魔睡地，越停留越困倦，有沉睡漂移的危险。天路客与盼望靠彼此交谈——谈十字架、谈忠信、谈前面的天城——与祷告、地图，保持警醒走过。",
        "story_en": "Ahead lies the beautiful but drowsy Enchanted Ground, where the longer one lingers the sleepier one grows, risking a sleepwalking drift. The pilgrim and Hopeful keep awake by talking together—of the Cross, of Faithful, of the City ahead—and by prayer and the map, passing through watchful.",
        "theme_zh": "终点前的最大危险不是攻击，而是属灵的麻木与安逸沉睡；保持警醒靠的是同行的提醒、祷告与记念。",
        "theme_en": "The greatest danger before the end is not assault but spiritual numbness and comfortable sleep; staying awake comes through fellowship's reminders, prayer, and remembrance.",
        "refs": [
            ref("不要睡觉，总要警醒", "Keep awake and sober", "帖撒罗尼迦前书 5:6", "1 Thessalonians 5:6",
                "我们不要睡觉，像别人一样，总要警醒谨守。", "Let us not sleep, as others do, but let us keep awake and be sober."),
            ref("总要警醒", "Watch!", "马可福音 13:37", "Mark 13:37",
                "我对你们所说的话，也是对众人说：要警醒！", "What I say to you I say to all: Stay awake!"),
            ref("彼此勉励", "Encourage one another", "希伯来书 3:13", "Hebrews 3:13",
                "总要趁着还有今日，天天彼此相劝，免得……心里就刚硬了。", "Encourage one another daily, that none be hardened by sin's deceitfulness."),
        ],
        "questions": [
            q("q1", "children", "魔睡地为什么这么危险？它会怎样让人停下来？", "Why is the Enchanted Ground so dangerous—how does it make you stop?"),
            q("q2", "youth", "盼望说『最怕同行的人彼此提醒』。为什么交谈能赶走属灵的困倦？", "Hopeful says the ground 'most fears companions reminding each other'. Why does talking drive off spiritual drowsiness?"),
            q("q3", "adult", "什么样的『安逸』最容易让你属灵上打盹？你用什么保持警醒？", "What kind of comfort most easily lulls you spiritually—what keeps you awake?"),
        ],
        "teacher_notes_zh": ["这里没有怪物，敌人是『舒服』本身——这正是它的隐蔽。", "保持警醒的操练是具体的：交谈、祷告、记念恩典，而非靠意志硬撑。"],
        "teacher_notes_en": ["No monster here—the enemy is comfort itself, which is its disguise.", "Staying awake is concrete: conversation, prayer, remembering grace—not sheer willpower."],
        "reflection_zh": "写下：我现在在哪方面属灵上『打盹』？这周我能与谁彼此提醒？",
        "reflection_en": "Write down: where am I spiritually dozing—who can I keep mutually awake with this week?",
        "prayer_zh": "主啊，求你叫我警醒不沉睡，借着同行者的交谈与祷告，常记念你的恩典与那城。",
        "prayer_en": "Lord, keep me awake, not asleep; through fellowship and prayer let me keep remembering your grace and the City.",
    },
    "river_of_death": {
        "order": 15, "title_zh": "死河", "title_en": "The River of Death",
        "story_zh": "美地之后是没有桥的死河——通往天城必须经过。河水随惧怕加深、随信心变浅；盼望在水中扶持天路客『记得你所信的是谁，不是看水有多深』，直到双脚踏上彼岸。",
        "story_en": "Beyond Beulah lies the bridgeless River of Death—the City cannot be reached but through it. The water deepens with fear and grows shallow with faith; in the water Hopeful steadies the pilgrim, 'remember the one you trust, not how deep the water is', until his feet touch the far bank.",
        "theme_zh": "死亡是最后的试炼，不能靠装备、财富或名声渡过，唯靠信靠基督；惧怕使水加深，信心使水变浅。",
        "theme_en": "Death is the final trial, crossed not by gear, wealth, or fame but by trust in Christ; fear deepens the water, faith makes it shallow.",
        "refs": [
            ref("经过水，我必同在", "Through the waters", "以赛亚书 43:2", "Isaiah 43:2",
                "你从水中经过，我必与你同在；你趟过江河，水必不漫过你。", "When you pass through the waters I will be with you; the rivers shall not overwhelm you."),
            ref("死被得胜吞灭", "Death swallowed in victory", "哥林多前书 15:55-57", "1 Corinthians 15:55-57",
                "死啊，你得胜的权势在哪里？……感谢神，使我们借着主耶稣基督得胜。", "O death, where is your victory? Thanks be to God, who gives us victory through our Lord Jesus Christ."),
            ref("不怕遭害，你与我同在", "I will fear no evil", "诗篇 23:4", "Psalm 23:4",
                "我虽然行过死荫的幽谷，也不怕遭害，因为你与我同在。", "Though I walk through the valley of the shadow of death, I will fear no evil, for you are with me."),
        ],
        "questions": [
            q("q1", "children", "为什么有时候水很深，有时候水很浅？", "Why is the water sometimes deep and sometimes shallow?"),
            q("q2", "youth", "盼望说『不要看水有多深，要记得你所信的是谁』。这对面对恐惧有什么帮助？", "Hopeful says 'don't look at the depth, remember the one you trust'. How does this help with fear?"),
            q("q3", "adult", "面对死亡或巨大的失去，什么使你的『水』变浅？什么使它变深？", "Facing death or great loss, what makes your 'water' shallow—what makes it deep?"),
        ],
        "teacher_notes_zh": ["不要把死河讲得恐怖；重点是『不是独自经过』与信靠。", "渡河不是凭感觉（感觉常说要沉了），而是凭所信的对象。"],
        "teacher_notes_en": ["Don't make the river ghoulish; the point is 'not crossing alone' and trust.", "Crossing is not by feeling (feeling says you're sinking) but by the One trusted."],
        "reflection_zh": "写下：什么『最后的河』是我惧怕的？哪一句应许能使那水变浅？",
        "reflection_en": "Write down: what 'last river' do I fear—which promise can make that water shallow?",
        "prayer_zh": "主啊，你应许我经过水时你与我同在；当我惧怕的水加深，求你叫我记得我所信的是你。",
        "prayer_en": "Lord, you promise to be with me through the waters; when fear's water deepens, make me remember the One I trust is you.",
    },
    "celestial_city": {
        "order": 16, "title_zh": "天城", "title_en": "The Celestial City",
        "story_zh": "上了彼岸，发光者迎接天路客，翻开旅程之书，回顾这一路每一步的恩典记号。城门为他敞开，他换上荣耀的白衣进城，全程归回敬拜——他不是凭功劳到达，而是被恩典一路带到天城。",
        "story_en": "Ashore, a Shining One greets the pilgrim and opens the Book of the Journey, recalling the mark of grace on every step. The gate opens; clothed in glory-white he enters, and the whole road gathers into worship—he arrived not by merit but carried all the way by grace.",
        "theme_zh": "荣耀的终局是恩典的总结，不是功劳的清算；回顾旅程是为记念拯救，进入永恒的安息与敬拜。",
        "theme_en": "The glory of the end is the sum of grace, not a tally of merit; the journey-review remembers salvation, entering eternal rest and worship.",
        "refs": [
            ref("神要擦去一切眼泪", "He will wipe away tears", "启示录 21:3-4", "Revelation 21:3-4",
                "神要……擦去他们一切的眼泪；不再有死亡，也不再有悲哀、哭号、疼痛。", "God will wipe away every tear; death shall be no more, nor mourning nor crying nor pain."),
            ref("生命河与生命树", "River and tree of life", "启示录 22:1-5", "Revelation 22:1-5",
                "天使又指示我一道生命水的河……河这边与那边有生命树。", "He showed me the river of the water of life… and the tree of life on either side."),
            ref("那美好的仗我已打过", "I have fought the good fight", "提摩太后书 4:7-8", "2 Timothy 4:7-8",
                "那美好的仗我已经打过了，当跑的路我已经跑尽了……有公义的冠冕为我存留。", "I have fought the good fight, I have finished the race… the crown of righteousness is laid up for me."),
        ],
        "questions": [
            q("q1", "children", "进天城以前，发光者和天路客一起做了什么？", "Before entering the City, what do the Shining One and the pilgrim do together?"),
            q("q2", "youth", "旅程之书回顾的是『恩典的记号』，不是『功劳的分数』。这两者有什么不同？", "The Book reviews 'marks of grace', not 'a score of merit'. What's the difference?"),
            q("q3", "adult", "回望你自己的属灵旅程，哪些『记号』最清楚地说明是恩典带你走到今天？", "Looking back on your own journey, which 'marks' most clearly show grace brought you here?"),
        ],
        "teacher_notes_zh": ["这是恩典的回顾，不是成就清单——避免把终局讲成奖励积分。", "可邀请学员写下自己的『旅程之书』：从灭亡城到今天的恩典记号。"],
        "teacher_notes_en": ["This is a grace-review, not an achievement list—avoid framing the end as reward points.", "Invite learners to write their own 'Book of the Journey': marks of grace from the City of Destruction to today."],
        "reflection_zh": "写下我自己的『旅程之书』：从我的『灭亡城』到今天，三个最清楚的恩典记号。",
        "reflection_en": "Write your own 'Book of the Journey': three clearest marks of grace from your 'City of Destruction' to today.",
        "prayer_zh": "主啊，那美好的仗求你帮助我打到底；我深知不是凭功劳，而是你的恩典一路带我回家。求你保守我直到天城。",
        "prayer_en": "Lord, help me fight the good fight to the end; I know it is not by merit but your grace carrying me home—keep me to the Celestial City.",
    },
}


def main():
    check_only = "--check" in sys.argv
    problems = []
    # Cross-check ids against the real chapter set.
    chapter_ids = {f[:-5] for f in os.listdir(CHAPTERS) if f.endswith(".json")}
    for cid, g in GUIDES.items():
        if cid not in chapter_ids:
            problems.append("guide '%s' has no matching data/chapters/%s.json" % (cid, cid))
        for ref_obj in g["refs"]:
            for k in ("label_zh", "label_en", "reference_zh", "reference_en", "note_zh", "note_en"):
                if not ref_obj.get(k):
                    problems.append("%s: ref missing '%s'" % (cid, k))
        for qq in g["questions"]:
            if qq["audience"] not in AUDIENCES:
                problems.append("%s: bad audience '%s'" % (cid, qq["audience"]))
    missing = chapter_ids - set(GUIDES)
    if missing:
        problems.append("no teaching guide for chapters: %s" % ", ".join(sorted(missing)))
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  - " + p)
        sys.exit(1)
    if check_only:
        print("CHECK OK: %d guides, all map to real chapters, refs/audiences valid." % len(GUIDES))
        return
    os.makedirs(OUT, exist_ok=True)
    for cid, g in GUIDES.items():
        doc = {"chapter_id": cid, "order": g["order"],
               "title_zh": g["title_zh"], "title_en": g["title_en"],
               "story_summary_zh": g["story_zh"], "story_summary_en": g["story_en"],
               "spiritual_theme_zh": g["theme_zh"], "spiritual_theme_en": g["theme_en"],
               "bible_references": g["refs"],
               "discussion_questions": g["questions"],
               "teacher_notes_zh": g["teacher_notes_zh"], "teacher_notes_en": g["teacher_notes_en"],
               "reflection_prompt_zh": g["reflection_zh"], "reflection_prompt_en": g["reflection_en"],
               "prayer_prompt_zh": g["prayer_zh"], "prayer_prompt_en": g["prayer_en"]}
        with open(os.path.join(OUT, cid + ".json"), "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print("Wrote %d teaching guides to data/teaching_guides/" % len(GUIDES))


if __name__ == "__main__":
    main()

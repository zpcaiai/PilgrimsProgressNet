import type { Dialogue } from '../types'

// Batch 1 dialogues (Chapter 1). Later batches add per-chapter dialogue files.
export const DIALOGUES: Record<string, Dialogue> = {
  dialogue_warning_scroll: {
    id: 'dialogue_warning_scroll', chapterId: 'chapter_01',
    lines: [
      { speaker: '旁白', textCN: '你展开手中的书卷，字句像火一样刺入心中。' },
      { speaker: '书卷', textCN: '这城将要倾覆。凡背负罪债的人，若不逃离，必与城一同灭亡。' },
    ],
    choices: [
      { id: 'read_done', textCN: '我该往哪里去？', effects: { vigilance: 8, burden: 5 }, setFlags: ['read_warning_scroll'], consequenceCN: '你的心被唤醒，开始寻找出路。' },
    ],
  },
  dialogue_evangelist_intro: {
    id: 'dialogue_evangelist_intro', chapterId: 'chapter_01',
    lines: [
      { speaker: '传福音者 Evangelist', textCN: '你为何哭泣？为何背着这样沉重的担子？' },
      { speaker: '天路客', textCN: '我读了书卷，知道这城将亡。我害怕，却不知道往哪里去。' },
      { speaker: '传福音者 Evangelist', textCN: '你看见远处那一点光吗？朝那里走。你会找到窄门。' },
    ],
    choices: [
      { id: 'accept_evangelist_call', textCN: '我愿意离开这城。', effects: { faith: 12, courage: 8, burden: -4 }, setFlags: ['accepted_evangelist_call'], addItems: ['scroll_of_warning'], consequenceCN: '你仍然害怕，但你的脚开始朝远处的光移动。' },
      { id: 'delay_response', textCN: '我还要再等等。', effects: { fear: 8, doubt: 5, burden: 6 }, setFlags: ['delayed_evangelist_call'], consequenceCN: '拖延使你的重担更沉，城中的声音也变得更大。' },
    ],
  },
  dialogue_obstinate_stay: {
    id: 'dialogue_obstinate_stay', chapterId: 'chapter_01',
    lines: [
      { speaker: '顽固 Obstinate', textCN: '你疯了吗？为了几句书卷上的话，就要离开自己的城？' },
    ],
    choices: [
      { id: 'argue_with_obstinate', textCN: '与他争辩，证明自己是对的。', effects: { pride: 10, vigilance: -5, burden: 4 }, setFlags: ['argued_with_obstinate'], consequenceCN: '你赢了争辩，却失去了一些内心的安静。' },
      { id: 'walk_away', textCN: '不争辩，继续寻找远处的光。', effects: { humility: 8, faith: 5, courage: 4 }, setFlags: ['refused_obstinate_argument'], consequenceCN: '你没有回答每一个嘲笑，而是继续前行。' },
    ],
  },
  dialogue_pliable_join: {
    id: 'dialogue_pliable_join', chapterId: 'chapter_01',
    lines: [
      { speaker: '易迁 Pliable', textCN: '你说的天城听起来不错，我也跟你去看看！' },
    ],
    choices: [
      { id: 'pliable_ok', textCN: '那就一同上路吧。', effects: { hope: 4 }, setFlags: ['pliable_joined'], consequenceCN: '易迁兴奋地跟上，但他的根基还很浅。' },
    ],
  },

  // --- Batch 2: NPC dialogues for later chapters (data ready before scenes) ---
  dialogue_help_rescue: {
    id: 'dialogue_help_rescue', chapterId: 'chapter_02',
    lines: [
      { speaker: '帮助 Help', textCN: '把手给我。沮丧的泥潭吞不住向上呼求的人。' },
    ],
    choices: [
      { id: 'take_help_hand', textCN: '抓住他的手。', effects: { hope: 10, despair: -10, humility: 6 }, setFlags: ['called_for_help', 'rescued_from_slough'], consequenceCN: '你被拉上坚实的踏脚石，重新站立。' },
    ],
  },
  dialogue_goodwill_gate: {
    id: 'dialogue_goodwill_gate', chapterId: 'chapter_02',
    lines: [
      { speaker: '善意 Goodwill', textCN: '叩门的就给他开门。进来吧，这是生命的道路。' },
    ],
    choices: [
      { id: 'enter_narrow_gate', textCN: '走进窄门。', effects: { faith: 10, hope: 8 }, setFlags: ['entered_narrow_gate'], consequenceCN: '门在身后关上，你正式踏上窄路。' },
    ],
  },
  dialogue_interpreter_welcome: {
    id: 'dialogue_interpreter_welcome', chapterId: 'chapter_03',
    lines: [
      { speaker: '讲解者 Interpreter', textCN: '我要给你看几样东西，路上会用得着。' },
      { speaker: '旁白', textCN: '油灯旁的火被暗中浇灌——恩典在你看不见处持续供应。' },
    ],
    choices: [
      { id: 'learn_from_rooms', textCN: '用心记下每个房间的功课。', effects: { vigilance: 10, faith: 6 }, setFlags: ['learned_interpreter_lessons'], addItems: ['chapel_candle'], consequenceCN: '你带着分辨的眼光离开讲解者的家。' },
    ],
  },
  dialogue_watchful_gate: {
    id: 'dialogue_watchful_gate', chapterId: 'chapter_07',
    lines: [
      { speaker: '警醒 Watchful', textCN: '前面是降卑谷与死荫幽谷。没有军装的人不可前行。' },
    ],
    choices: [
      { id: 'receive_armory', textCN: '我愿意领受神所赐的全副军装。', effects: { faith: 8, courage: 8, vigilance: 6 }, setFlags: ['entered_armory'], consequenceCN: '警醒带你走入兵器库。' },
    ],
  },
  dialogue_faithful_meeting: {
    id: 'dialogue_faithful_meeting', chapterId: 'chapter_10',
    lines: [
      { speaker: '忠信 Faithful', textCN: '我也是从灭亡城出来的。我们一同走完这段路吧。' },
    ],
    choices: [
      { id: 'welcome_faithful', textCN: '有同伴真好，一起走。', effects: { hope: 8, courage: 6, love: 6 }, setFlags: ['faithful_joined'], consequenceCN: '忠信与你并肩，准备进入虚华市。' },
    ],
  },
  dialogue_hopeful_join: {
    id: 'dialogue_hopeful_join', chapterId: 'chapter_12',
    lines: [
      { speaker: '盼望 Hopeful', textCN: '我因忠信的见证而信。如今我接续他，与你同行。' },
    ],
    choices: [
      { id: 'welcome_hopeful', textCN: '愿我们一同坚持到底。', effects: { hope: 15, courage: 8 }, setFlags: ['hopeful_joined'], addItems: ['hopeful_cross'], consequenceCN: '殉道的火没有熄灭见证，反而点燃了盼望。' },
    ],
  },
  dialogue_apollyon_accusation: {
    id: 'dialogue_apollyon_accusation', chapterId: 'chapter_09',
    lines: [
      { speaker: '亚玻伦 Apollyon', textCN: '（牛头鬼怪喷着浓烟）你本是我的子民！历数你一路的失败——你凭什么前行？' },
    ],
    choices: [
      { id: 'stand_in_armor', textCN: '举起信德的盾，拔出圣灵的宝剑。', effects: { courage: 12, faith: 10, accusation: -8 }, setFlags: ['stood_against_apollyon'], consequenceCN: '你不靠自己的义，乃靠那为你死而复活的主而站立。' },
    ],
  },
  dialogue_giant_despair_threat: {
    id: 'dialogue_giant_despair_threat', chapterId: 'chapter_13',
    lines: [
      { speaker: '绝望巨人 Giant Despair', textCN: '你们擅闯我的地界！在我的疑惑堡里，活着不如死了。' },
    ],
    choices: [
      { id: 'cling_to_promise', textCN: '与盼望一同祷告，回想神的应许。', effects: { hope: 10, despair: -10, faith: 6 }, setFlags: ['prayed_in_castle'], consequenceCN: '黑暗中升起一线微光——你想起怀里的应许之钥。' },
    ],
  },
}

export function getDialogueById(id: string): Dialogue | undefined {
  return DIALOGUES[id]
}

import type { GameState } from '../types'

export type FlowObjective = { id: string; labelCN: string; completed: boolean }

export type ChapterFlow = {
  objectives: (gs: GameState) => FlowObjective[]
  canAdvance: (gs: GameState) => boolean
  advanceLabel: string
  next?: { chapterId: string; sceneId: string }
}

const f = (gs: GameState) => gs.storyFlags

/**
 * Per-chapter objectives + the condition/label for advancing to the next scene.
 * Batch 3 fills chapters 1–4; later batches extend this map.
 */
export const CHAPTER_FLOW: Record<string, ChapterFlow> = {
  chapter_01: {
    objectives: (gs) => [
      { id: 'read', labelCN: '阅读手中的书卷', completed: !!f(gs).read_warning_scroll },
      { id: 'talk', labelCN: '与传福音者交谈', completed: !!f(gs).accepted_evangelist_call || !!f(gs).delayed_evangelist_call },
      { id: 'choose', labelCN: '回应呼召（接受离城）', completed: !!f(gs).accepted_evangelist_call },
    ],
    canAdvance: (gs) => !!f(gs).accepted_evangelist_call,
    advanceLabel: '出城门 → 沮丧泥潭',
    next: { chapterId: 'chapter_02', sceneId: 'slough_of_despond' },
  },
  chapter_02: {
    objectives: (gs) => [
      { id: 'slough', labelCN: '在沮丧泥潭中呼求“帮助”', completed: !!f(gs).called_for_help || !!f(gs).rescued_from_slough },
      { id: 'gate', labelCN: '叩窄门，蒙“善意”接纳', completed: !!f(gs).entered_narrow_gate },
    ],
    canAdvance: (gs) => !!f(gs).entered_narrow_gate,
    advanceLabel: '进入窄门 → 讲解者的家',
    next: { chapterId: 'chapter_03', sceneId: 'interpreter_house_interior' },
  },
  chapter_03: {
    objectives: (gs) => [
      { id: 'learn', labelCN: '完成讲解者房间的功课', completed: !!f(gs).learned_interpreter_lessons },
    ],
    canAdvance: (gs) => !!f(gs).learned_interpreter_lessons,
    advanceLabel: '前往各各他的十字架',
    next: { chapterId: 'chapter_04', sceneId: 'calvary_hill' },
  },
  chapter_04: {
    objectives: (gs) => [
      { id: 'cross', labelCN: '跪在十字架前，重担脱落', completed: !!f(gs).burden_lifted },
      { id: 'garment', labelCN: '领受新衣与确据书卷', completed: gs.inventory.items.includes('new_garment') },
    ],
    canAdvance: (gs) => !!f(gs).burden_lifted,
    advanceLabel: '继续上路 → 困难山',
    next: { chapterId: 'chapter_05', sceneId: 'hill_difficulty_base' },
  },
  chapter_05: {
    objectives: (gs) => [
      { id: 'climb', labelCN: '选择窄而陡的正路登山', completed: !!f(gs).climbed_difficulty },
      { id: 'awake', labelCN: '警醒，不在凉亭沉睡失书', completed: !f(gs).lost_scroll_at_arbor && !!f(gs).climbed_difficulty },
    ],
    canAdvance: (gs) => !!f(gs).climbed_difficulty,
    advanceLabel: '登上山顶 → 美宫',
    next: { chapterId: 'chapter_06', sceneId: 'house_beautiful_interior' },
  },
  chapter_06: {
    objectives: (gs) => [
      { id: 'rest', labelCN: '在美宫团契中安息', completed: !!f(gs).rested_house_beautiful },
    ],
    canAdvance: (gs) => !!f(gs).rested_house_beautiful,
    advanceLabel: '前往军装厅',
    next: { chapterId: 'chapter_07', sceneId: 'armory_hall' },
  },
  chapter_07: {
    objectives: (gs) => [
      { id: 'armor', labelCN: '领取神所赐的全副军装（弗 6）', completed: !!f(gs).received_full_armor },
    ],
    canAdvance: (gs) => !!f(gs).received_full_armor,
    advanceLabel: '披甲下到降卑谷',
    next: { chapterId: 'chapter_08', sceneId: 'valley_humiliation_floor' },
  },
  chapter_08: {
    objectives: (gs) => [
      { id: 'humble', labelCN: '俯首谦卑，预备直面控告者', completed: !!f(gs).humbled_in_valley },
    ],
    canAdvance: (gs) => !!f(gs).humbled_in_valley,
    advanceLabel: '直面亚玻伦（第 9 章）',
    next: { chapterId: 'chapter_09', sceneId: 'apollyon_arena' },
  },
  chapter_09: {
    objectives: (gs) => [
      { id: 'stand', labelCN: '披着军装直面控告者', completed: !!f(gs).stood_against_apollyon },
      { id: 'defeat', labelCN: '以信德盾与圣灵剑击退亚玻伦', completed: !!f(gs).defeated_apollyon || gs.bosses.apollyonDefeated },
    ],
    canAdvance: (gs) => !!f(gs).defeated_apollyon || gs.bosses.apollyonDefeated,
    advanceLabel: '走入死荫幽谷',
    next: { chapterId: 'chapter_10', sceneId: 'valley_shadow_death' },
  },
  chapter_10: {
    objectives: (gs) => [
      { id: 'cross', labelCN: '不偏左右，走过死荫的幽谷', completed: !!f(gs).crossed_shadow_valley },
      { id: 'faithful', labelCN: '在谷口与忠信结伴同行', completed: !!f(gs).faithful_joined },
    ],
    canAdvance: (gs) => !!f(gs).crossed_shadow_valley && !!f(gs).faithful_joined,
    advanceLabel: '与忠信同往虚华市',
    next: { chapterId: 'chapter_11', sceneId: 'vanity_fair' },
  },
  chapter_11: {
    objectives: (gs) => [
      { id: 'refuse', labelCN: '不买世界的虚荣，只买真理', completed: !!f(gs).refused_vanity_fame },
    ],
    canAdvance: (gs) => !!f(gs).refused_vanity_fame,
    advanceLabel: '前往忠信受审之地',
    next: { chapterId: 'chapter_12', sceneId: 'trial_of_faithful' },
  },
  chapter_12: {
    objectives: (gs) => [
      { id: 'stand', labelCN: '公开站在忠信一边作见证', completed: !!f(gs).stood_with_faithful },
      { id: 'martyr', labelCN: '忠信殉道，盼望兴起接续同行', completed: !!f(gs).hopeful_joined },
    ],
    canAdvance: (gs) => !!f(gs).faithful_martyred && !!f(gs).hopeful_joined,
    advanceLabel: '前往疑惑堡（第 13 章）',
    next: { chapterId: 'chapter_13', sceneId: 'doubting_castle' },
  },
  chapter_13: {
    objectives: (gs) => [
      { id: 'key', labelCN: '想起怀中的应许之钥', completed: !!f(gs).found_key_of_promise },
      { id: 'escape', labelCN: '逃出疑惑堡，胜过绝望巨人', completed: !!f(gs).escaped_doubting_castle || gs.bosses.giantDespairDefeated },
    ],
    canAdvance: (gs) => !!f(gs).escaped_doubting_castle || gs.bosses.giantDespairDefeated,
    advanceLabel: '逃出疑惑堡 → 可喜山',
    next: { chapterId: 'chapter_14', sceneId: 'delectable_mountains' },
  },
  chapter_14: {
    objectives: (gs) => [
      { id: 'shepherds', labelCN: '受牧人接待，领取牧人地图', completed: !!f(gs).met_shepherds },
      { id: 'awake', labelCN: '警醒，不在魔睡地沉睡', completed: !!f(gs).resisted_enchanted_sleep },
    ],
    canAdvance: (gs) => !!f(gs).resisted_enchanted_sleep,
    advanceLabel: '下山 → 死河',
    next: { chapterId: 'chapter_15', sceneId: 'river_of_death' },
  },
  chapter_15: {
    objectives: (gs) => [
      { id: 'cross', labelCN: '凭信渡过死河，盼望扶持', completed: !!f(gs).crossed_river },
    ],
    canAdvance: (gs) => !!f(gs).crossed_river,
    advanceLabel: '上彼岸 → 天城',
    next: { chapterId: 'chapter_16', sceneId: 'celestial_city' },
  },
  chapter_16: {
    objectives: (gs) => [
      { id: 'enter', labelCN: '进入天城的门，领受生命冠冕', completed: !!f(gs).entered_celestial_city },
    ],
    canAdvance: () => false, // the finale is sealed by the Ending Review overlay
    advanceLabel: '',
  },
}

export function getChapterFlow(chapterId: string): ChapterFlow | undefined {
  return CHAPTER_FLOW[chapterId]
}

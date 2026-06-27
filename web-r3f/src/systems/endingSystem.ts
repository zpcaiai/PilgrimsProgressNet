import type { GameState, StatKey } from '../types'
import { CHAPTERS, getItemById, getNpcById } from '../lib/content'

// ---------------------------------------------------------------------------
// Batch 6 — the ending review. Distils the whole journey (milestones, virtues,
// companions, keepsakes, and the running tallies) into a summary the Celestial
// City screen renders. Pure read of GameState.
// ---------------------------------------------------------------------------

export type EndingMilestone = { id: string; labelCN: string; achieved: boolean }
export type EndingVirtue = { key: StatKey; labelCN: string; value: number }

export type EndingSummary = {
  chaptersCompleted: number
  totalChapters: number
  virtues: EndingVirtue[]
  milestones: EndingMilestone[]
  resistedTemptations: number
  chapelVisits: number
  repentedTimes: number
  companionsCN: string[]
  keepsakesCN: string[]
  score: number
  rankCN: string
}

const VIRTUE_LABELS: [StatKey, string][] = [
  ['faith', '信心'], ['hope', '盼望'], ['love', '爱心'], ['humility', '谦卑'],
  ['vigilance', '警醒'], ['courage', '勇气'], ['witness', '见证'],
]

const KEEPSAKE_ORDER = ['crown_of_life', 'faithful_witness_token', 'hopeful_cross', 'key_of_promise', 'scroll_of_assurance', 'new_garment']

export function buildEndingSummary(gs: GameState): EndingSummary {
  const f = gs.storyFlags
  const milestones: EndingMilestone[] = [
    { id: 'burden', labelCN: '在十架前卸下重担', achieved: !!f.burden_lifted },
    { id: 'armor', labelCN: '披戴神所赐的全副军装', achieved: !!f.received_full_armor },
    { id: 'apollyon', labelCN: '靠信德盾击退亚玻伦', achieved: gs.bosses.apollyonDefeated },
    { id: 'shadow', labelCN: '走过死荫的幽谷', achieved: !!f.crossed_shadow_valley },
    { id: 'vanity', labelCN: '在虚华市不爱世界', achieved: !!f.refused_vanity_fame },
    { id: 'faithful', labelCN: '与忠信一同作见证', achieved: !!f.faithful_martyred },
    { id: 'castle', labelCN: '以应许之钥逃出疑惑堡', achieved: !!f.escaped_doubting_castle },
    { id: 'enchanted', labelCN: '在魔睡地保持警醒', achieved: !!f.resisted_enchanted_sleep },
    { id: 'river', labelCN: '凭信渡过死河', achieved: !!f.crossed_river },
    { id: 'city', labelCN: '进入天城，领受生命冠冕', achieved: !!f.entered_celestial_city },
  ]
  const virtues: EndingVirtue[] = VIRTUE_LABELS.map(([key, labelCN]) => ({ key, labelCN, value: gs.spiritualStats[key] }))
  const companionsCN = gs.companions.map((c) => {
    const npc = getNpcById(c.npcId)
    const tag = c.storyState === 'martyred' ? '（殉道）' : c.isActive ? '（同行）' : '（曾同行）'
    return `${npc?.nameCN ?? c.npcId}${tag}`
  })
  const keepsakesCN = KEEPSAKE_ORDER
    .filter((id) => gs.inventory.items.includes(id))
    .map((id) => getItemById(id)?.nameCN ?? id)

  const milestoneScore = milestones.filter((m) => m.achieved).length * 8
  const virtueScore = virtues.reduce((a, v) => a + v.value, 0) / virtues.length
  const tallyScore = gs.endingReview.resistedTemptations * 3 + gs.endingReview.chapelVisits * 2 + gs.endingReview.repentedTimes * 2
  const score = Math.round(milestoneScore + virtueScore + tallyScore)
  const rankCN = score >= 150 ? '忠心又良善的仆人'
    : score >= 110 ? '坚忍到底的天路客'
    : score >= 70 ? '蒙恩前行的旅人'
    : '初上路的天路客'

  return {
    chaptersCompleted: gs.chapters.completedChapterIds.length,
    totalChapters: CHAPTERS.length,
    virtues,
    milestones,
    resistedTemptations: gs.endingReview.resistedTemptations,
    chapelVisits: gs.endingReview.chapelVisits,
    repentedTimes: gs.endingReview.repentedTimes,
    companionsCN,
    keepsakesCN,
    score,
    rankCN,
  }
}

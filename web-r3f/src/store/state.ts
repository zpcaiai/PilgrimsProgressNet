import type { GameState, SpiritualStats, StatKey } from '../types'

export const initialSpiritualStats: SpiritualStats = {
  faith: 20, hope: 20, love: 10, humility: 10, vigilance: 10, courage: 10,
  burden: 80, worldliness: 40, doubt: 20, despair: 10,
  fear: 15, pride: 10, accusation: 0, witness: 0,
}

export function clampStats(s: SpiritualStats): SpiritualStats {
  const c = (v: number) => Math.max(0, Math.min(100, Math.round(v)))
  const out = {} as SpiritualStats
  ;(Object.keys(s) as StatKey[]).forEach((k) => { out[k] = c(s[k]) })
  return out
}

export function applyStatDelta(s: SpiritualStats, delta: Partial<SpiritualStats>): SpiritualStats {
  const next: SpiritualStats = { ...s }
  ;(Object.keys(delta) as StatKey[]).forEach((k) => {
    next[k] = (next[k] ?? 0) + (delta[k] ?? 0)
  })
  return clampStats(next)
}

export function createInitialGameState(): GameState {
  return {
    player: {
      id: 'pilgrim', name: 'Christian',
      currentChapterId: 'chapter_01', currentSceneId: 'city_of_destruction',
      position: [0, 0, 6], identityStage: 'awakened',
      level: 1, hp: 100, maxHp: 100,
    },
    spiritualStats: { ...initialSpiritualStats },
    inventory: { items: [], equipped: {} },
    quests: { activeQuestIds: ['quest_awaken_in_city'], completedQuestIds: [], failedQuestIds: [] },
    chapters: { unlockedChapterIds: ['chapter_01'], completedChapterIds: [] },
    storyFlags: {},
    visitedChapels: [],
    choices: [],
    activeTemptations: [],
    companions: [],
    bosses: { apollyonDefeated: false, giantDespairDefeated: false },
    endingReview: { helpedNPCs: 0, resistedTemptations: 0, repentedTimes: 0, chapelVisits: 0, faithfulWitnessScore: 0 },
  }
}

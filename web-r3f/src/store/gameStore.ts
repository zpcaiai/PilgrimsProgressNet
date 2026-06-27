import { create } from 'zustand'
import type { GameState, SpiritualStats } from '../types'
import { createInitialGameState, applyStatDelta } from './state'
import { refreshIdentityStage } from '../systems/identitySystem'

const SAVE_KEY = 'pilgrim_progress_save'

export type GameStore = {
  gameState: GameState
  updateStats: (delta: Partial<SpiritualStats>) => void
  addItem: (itemId: string) => void
  setFlag: (flag: string, value?: boolean) => void
  /** Apply a choice/dialogue outcome: stat deltas + flags + items, then autosave. */
  applyEffects: (effects?: Partial<SpiritualStats>, flags?: string[], items?: string[]) => void
  /** Apply any pure system function (GameState -> GameState), refresh identity, autosave. */
  mutate: (fn: (gs: GameState) => GameState) => void
  visitChapel: (chapelId: string) => void
  recordChoice: (chapterId: string, choiceId: string, consequence: string) => void
  completeQuest: (questId: string) => void
  completeChapter: (chapterId: string, nextChapterId?: string) => void
  goTo: (chapterId: string, sceneId: string) => void
  saveGame: () => void
  loadGame: () => boolean
  hasSave: () => boolean
  resetGame: () => void
  /** Start the journey again, carrying a modest boon + the new_game_plus flag. */
  newGamePlus: () => void
}

export const useGameStore = create<GameStore>((set, get) => ({
  gameState: createInitialGameState(),

  updateStats: (delta) => set((s) => ({
    gameState: { ...s.gameState, spiritualStats: applyStatDelta(s.gameState.spiritualStats, delta) },
  })),

  addItem: (itemId) => set((s) => (
    s.gameState.inventory.items.includes(itemId)
      ? s
      : { gameState: { ...s.gameState, inventory: { ...s.gameState.inventory, items: [...s.gameState.inventory.items, itemId] } } }
  )),

  setFlag: (flag, value = true) => set((s) => ({
    gameState: { ...s.gameState, storyFlags: { ...s.gameState.storyFlags, [flag]: value } },
  })),

  applyEffects: (effects, flags, items) => {
    const s = get().gameState
    const spiritualStats = effects ? applyStatDelta(s.spiritualStats, effects) : s.spiritualStats
    const storyFlags = { ...s.storyFlags }
    ;(flags ?? []).forEach((f) => { storyFlags[f] = true })
    const itemList = [...s.inventory.items]
    ;(items ?? []).forEach((it) => { if (!itemList.includes(it)) itemList.push(it) })
    set({ gameState: refreshIdentityStage({ ...s, spiritualStats, storyFlags, inventory: { ...s.inventory, items: itemList } }) })
    get().saveGame()
  },

  mutate: (fn) => {
    set((s) => ({ gameState: refreshIdentityStage(fn(s.gameState)) }))
    get().saveGame()
  },

  visitChapel: (chapelId) => {
    set((s) => ({
      gameState: {
        ...s.gameState,
        visitedChapels: Array.from(new Set([...s.gameState.visitedChapels, chapelId])),
        endingReview: { ...s.gameState.endingReview, chapelVisits: s.gameState.endingReview.chapelVisits + 1 },
      },
    }))
    get().saveGame()
  },

  recordChoice: (chapterId, choiceId, consequence) => set((s) => ({
    gameState: {
      ...s.gameState,
      choices: [...s.gameState.choices, { id: crypto.randomUUID(), chapterId, choiceId, consequence, timestamp: Date.now() }],
    },
  })),

  completeQuest: (questId) => set((s) => ({
    gameState: {
      ...s.gameState,
      quests: {
        ...s.gameState.quests,
        activeQuestIds: s.gameState.quests.activeQuestIds.filter((q) => q !== questId),
        completedQuestIds: Array.from(new Set([...s.gameState.quests.completedQuestIds, questId])),
      },
    },
  })),

  completeChapter: (chapterId, nextChapterId) => {
    set((s) => {
      const completedChapterIds = Array.from(new Set([...s.gameState.chapters.completedChapterIds, chapterId]))
      const unlockedChapterIds = nextChapterId
        ? Array.from(new Set([...s.gameState.chapters.unlockedChapterIds, nextChapterId]))
        : s.gameState.chapters.unlockedChapterIds
      return { gameState: { ...s.gameState, chapters: { unlockedChapterIds, completedChapterIds } } }
    })
    get().saveGame()
  },

  goTo: (chapterId, sceneId) => {
    set((s) => ({ gameState: { ...s.gameState, player: { ...s.gameState.player, currentChapterId: chapterId, currentSceneId: sceneId } } }))
    get().saveGame()
  },

  saveGame: () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(get().gameState)) } catch { /* ignore */ } },
  loadGame: () => {
    try {
      const raw = localStorage.getItem(SAVE_KEY)
      if (!raw) return false
      set({ gameState: JSON.parse(raw) as GameState })
      return true
    } catch { return false }
  },
  hasSave: () => { try { return !!localStorage.getItem(SAVE_KEY) } catch { return false } },
  resetGame: () => { set({ gameState: createInitialGameState() }); try { localStorage.removeItem(SAVE_KEY) } catch { /* ignore */ } },

  newGamePlus: () => {
    const fresh = createInitialGameState()
    const seasoned = refreshIdentityStage({
      ...fresh,
      // a pilgrim who finished once starts a little surer of the way
      spiritualStats: applyStatDelta(fresh.spiritualStats, { faith: 10, hope: 10, vigilance: 6, courage: 4 }),
      storyFlags: { new_game_plus: true },
    })
    set({ gameState: seasoned })
    get().saveGame()
  },
}))

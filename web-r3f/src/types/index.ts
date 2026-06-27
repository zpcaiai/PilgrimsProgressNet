// ---------------------------------------------------------------------------
// Core shared types for the 16-chapter Pilgrim's Progress game.
// Batch 1 defines the full GameState shape up front so later batches
// (NPC/choice/temptation/repentance/armor/companion) are purely additive.
// ---------------------------------------------------------------------------

export type SpiritualStats = {
  faith: number       // 信心
  hope: number        // 盼望
  love: number        // 爱心
  humility: number    // 谦卑
  vigilance: number   // 警醒
  courage: number     // 勇气
  burden: number      // 重担 (negative — lowered at the Cross)
  worldliness: number // 属世
  doubt: number       // 疑惑
  despair: number     // 绝望
  fear: number        // 惧怕
  pride: number       // 骄傲
  accusation: number  // 控告压力
  witness: number     // 见证勇气
}

// Positive stats grow toward the City; negative ones are pressures to overcome.
export const NEGATIVE_STATS: StatKey[] = [
  'burden', 'worldliness', 'doubt', 'despair', 'fear', 'pride', 'accusation',
]

export type StatKey = keyof SpiritualStats

export type PlayerIdentityStage =
  | 'awakened' | 'burdened' | 'forgiven' | 'equipped' | 'tested'
  | 'witnessing' | 'doubting' | 'hopeful' | 'crossing' | 'glorified'

export type PlayerEquipment = {
  belt?: string
  breastplate?: string
  shoes?: string
  shield?: string
  helmet?: string
  sword?: string
  armor?: string
  weapon?: string
  special?: string
}

export type ChoiceRecord = {
  id: string
  chapterId: string
  choiceId: string
  consequence: string
  timestamp: number
}

export type GameState = {
  player: {
    id: string
    name: string
    currentChapterId: string
    currentSceneId: string
    position: [number, number, number]
    identityStage: PlayerIdentityStage
    level: number
    hp: number
    maxHp: number
  }
  spiritualStats: SpiritualStats
  inventory: {
    items: string[]
    equipped: PlayerEquipment
  }
  quests: {
    activeQuestIds: string[]
    completedQuestIds: string[]
    failedQuestIds: string[]
  }
  chapters: {
    unlockedChapterIds: string[]
    completedChapterIds: string[]
  }
  storyFlags: Record<string, boolean>
  visitedChapels: string[]
  choices: ChoiceRecord[]
  activeTemptations: string[]
  companions: CompanionState[]
  bosses: {
    apollyonDefeated: boolean
    giantDespairDefeated: boolean
  }
  endingReview: {
    helpedNPCs: number
    resistedTemptations: number
    repentedTimes: number
    chapelVisits: number
    faithfulWitnessScore: number
  }
}

// Forward-declared (fleshed out in Batch 2) so GameState compiles now.
export type CompanionState = {
  npcId: string
  isActive: boolean
  joinedChapterId: string
  leftChapterId?: string
  bond: number
  storyState: string
}

export type Chapter = {
  id: string
  order: number
  titleCN: string
  titleEN: string
  theme: string
  mainSceneId: string
  mainSymbol: string
  chapelRequired: boolean
  requiredItems: string[]
  rewardItems: string[]
  faithLesson: string
  majorNPCs: string[]
  mainTemptation: string
  repentanceOpportunity: string
  completionCondition: string
}

export type ChapelType =
  | 'ruined' | 'gate' | 'calvary' | 'pilgrim' | 'trial' | 'river' | 'celestial'

export type ChapelData = {
  id: string
  chapterId: string
  type: ChapelType
  sceneId: string
  position: [number, number, number]
  rotation?: [number, number, number]
  verseText: string
  restoreFaithAmount: number
  unlocksQuestHint?: string
}

export type QuestObjective = {
  id: string
  labelCN: string
  completed: boolean
}

export type Quest = {
  id: string
  chapterId: string
  titleCN: string
  descriptionCN: string
  objectives: QuestObjective[]
}

export type ItemCategory =
  | 'scroll' | 'key' | 'armor' | 'temptation' | 'quest' | 'light' | 'companion_token'

export type GameItem = {
  id: string
  nameCN: string
  nameEN: string
  category: ItemCategory
  descriptionCN: string
  effects?: Partial<SpiritualStats>
  negativeEffects?: Partial<SpiritualStats>
  icon: string
}

export type NPCType =
  | 'guide' | 'companion' | 'teacher' | 'tempter' | 'enemy' | 'witness' | 'shepherd'

export type NPC = {
  id: string
  nameCN: string
  nameEN: string
  type: NPCType
  chapters: string[]
  symbol: string
  role: string
  defaultDialogueId: string
}

// A simple dialogue line + choice shape used by the Batch-1 placeholder scene.
export type DialogueChoice = {
  id: string
  textCN: string
  effects?: Partial<SpiritualStats>
  setFlags?: string[]
  addItems?: string[]
  consequenceCN?: string
}

export type DialogueLine = { speaker: string; textCN: string }

export type Dialogue = {
  id: string
  chapterId: string
  lines: DialogueLine[]
  choices?: DialogueChoice[]
}

// ---------------------------------------------------------------------------
// Batch 2 — systems: items, armor, temptation, choices, repentance, companions
// ---------------------------------------------------------------------------

export type ItemRarity = 'common' | 'important' | 'sacred' | 'dangerous' | 'unique'

export type FullItem = GameItem & {
  rarity: ItemRarity
  symbolMeaningCN?: string
  usable?: boolean
  equippable?: boolean
  consumable?: boolean
  countersTemptations?: TemptationType[]
}

export type ArmorSlot = 'belt' | 'breastplate' | 'shoes' | 'shield' | 'helmet' | 'sword'

export type SacredArmor = {
  id: string
  slot: ArmorSlot
  nameCN: string
  nameEN: string
  descriptionCN: string
  biblicalSymbolCN: string
  grantedInChapter: string
  statBonuses: Partial<SpiritualStats>
  countersTemptations: TemptationType[]
}

export type TemptationType =
  | 'fear' | 'worldliness' | 'pride' | 'doubt' | 'despair' | 'sleepiness' | 'accusation'

export type TemptationOutcome = {
  messageCN: string
  effects?: Partial<SpiritualStats>
  setFlags?: string[]
}

export type Temptation = {
  id: string
  chapterId: string
  sceneId: string
  type: TemptationType
  titleCN: string
  descriptionCN: string
  intensity: number
  instantEffects?: Partial<SpiritualStats>
  effectsPerTick?: Partial<SpiritualStats>
  resistedBy: { stats?: Partial<SpiritualStats>; items?: string[]; flags?: string[] }
  onResist?: TemptationOutcome
  onFail?: TemptationOutcome
}

export type SpiritualChoiceType =
  | 'obedience' | 'fear' | 'pride' | 'repentance' | 'compassion' | 'witness'
  | 'worldliness' | 'perseverance' | 'shortcut' | 'despair' | 'faith' | 'hope'
  | 'humility' | 'vigilance' | 'restoration'

export type SpiritualChoiceOption = {
  id: string
  textCN: string
  effects: Partial<SpiritualStats>
  setFlags?: string[]
  addItems?: string[]
  removeItems?: string[]
  consequenceCN: string
}

export type SpiritualChoice = {
  id: string
  chapterId: string
  sceneId: string
  type: SpiritualChoiceType
  promptCN: string
  repeatable: boolean
  requiredFlags?: string[]
  blockedByFlags?: string[]
  options: SpiritualChoiceOption[]
}

export type RepentanceStage =
  | 'conviction' | 'confession' | 'turning' | 'receiving_grace' | 'renewed_path'

export type RepentanceOption = {
  id: string
  textCN: string
  effects: Partial<SpiritualStats>
  setFlags?: string[]
}

export type RepentanceEvent = {
  id: string
  chapterId: string
  sceneId: string
  triggerReason:
    | 'high_burden' | 'high_worldliness' | 'high_doubt' | 'high_despair'
    | 'failed_temptation' | 'chapel_prayer' | 'npc_guidance' | 'boss_accusation'
  titleCN: string
  promptCN: string
  confessionOptions: RepentanceOption[]
  graceOutcome: {
    effects: Partial<SpiritualStats>
    removeFlags?: string[]
    setFlags?: string[]
    addItems?: string[]
    messageCN: string
  }
}

export type CompanionAbility = {
  id: string
  nameCN: string
  descriptionCN: string
  cooldownSeconds: number
  effects: Partial<SpiritualStats>
  countersTemptations?: TemptationType[]
}

import type {
  Chapter, ChapelData, NPC, FullItem, SacredArmor, SpiritualChoice,
  Temptation, RepentanceEvent, CompanionAbility, ArmorSlot,
} from '../types'
import chaptersData from '../data/chapters.json'
import chapelsData from '../data/chapels.json'
import npcsData from '../data/npcs.json'
import itemsData from '../data/items.json'
import armorData from '../data/sacredArmor.json'
import choicesData from '../data/choices.json'
import temptationsData from '../data/temptations.json'
import repentanceData from '../data/repentanceEvents.json'
import companionAbilitiesData from '../data/companionAbilities.json'

export const CHAPTERS: Chapter[] = (chaptersData as unknown as { chapters: Chapter[] }).chapters
export const CHAPELS: ChapelData[] = (chapelsData as unknown as { chapels: ChapelData[] }).chapels
export const NPCS: NPC[] = (npcsData as unknown as { npcs: NPC[] }).npcs
export const ITEMS: FullItem[] = (itemsData as unknown as { items: FullItem[] }).items
export const SACRED_ARMOR: SacredArmor[] = (armorData as unknown as { armor: SacredArmor[] }).armor
export const SPIRITUAL_CHOICES: SpiritualChoice[] = (choicesData as unknown as { choices: SpiritualChoice[] }).choices
export const TEMPTATIONS: Temptation[] = (temptationsData as unknown as { temptations: Temptation[] }).temptations
export const REPENTANCE_EVENTS: RepentanceEvent[] = (repentanceData as unknown as { events: RepentanceEvent[] }).events
export const COMPANION_ABILITIES: { npcId: string; abilities: CompanionAbility[] }[] =
  (companionAbilitiesData as unknown as { companions: { npcId: string; abilities: CompanionAbility[] }[] }).companions

export function getNpcById(id: string): NPC | undefined { return NPCS.find((n) => n.id === id) }
export function getItemById(id: string): FullItem | undefined { return ITEMS.find((i) => i.id === id) }
export function getArmorById(id: string): SacredArmor | undefined { return SACRED_ARMOR.find((a) => a.id === id) }
export function getArmorForSlot(slot: ArmorSlot): SacredArmor | undefined { return SACRED_ARMOR.find((a) => a.slot === slot) }
export function getChoiceById(id: string): SpiritualChoice | undefined { return SPIRITUAL_CHOICES.find((c) => c.id === id) }
export function getChoicesForScene(sceneId: string): SpiritualChoice[] { return SPIRITUAL_CHOICES.filter((c) => c.sceneId === sceneId) }
export function getTemptationById(id: string): Temptation | undefined { return TEMPTATIONS.find((t) => t.id === id) }
export function getTemptationsForScene(sceneId: string): Temptation[] { return TEMPTATIONS.filter((t) => t.sceneId === sceneId) }
export function getRepentanceById(id: string): RepentanceEvent | undefined { return REPENTANCE_EVENTS.find((r) => r.id === id) }
export function getCompanionAbilities(npcId: string): CompanionAbility[] {
  return COMPANION_ABILITIES.find((c) => c.npcId === npcId)?.abilities ?? []
}

export const ARMOR_SLOT_ORDER: ArmorSlot[] = ['belt', 'breastplate', 'shoes', 'shield', 'helmet', 'sword']

export function getChapterById(id: string): Chapter | undefined {
  return CHAPTERS.find((c) => c.id === id)
}

export function getNextChapter(id: string): Chapter | null {
  const c = getChapterById(id)
  if (!c) return null
  return CHAPTERS.find((x) => x.order === c.order + 1) ?? null
}

export function getChapelsForScene(sceneId: string): ChapelData[] {
  return CHAPELS.filter((c) => c.sceneId === sceneId)
}

export function getChapelById(id: string): ChapelData | undefined {
  return CHAPELS.find((c) => c.id === id)
}

// Chapel interactions (Batch 1). Pray restores faith/hope; repent humbles and
// lifts burden/despair. Grace-first: never a penalty, always a path back.
export const PRAY_EFFECTS = { faith: 8, hope: 5, fear: -4 } as const
export const REPENT_EFFECTS = { humility: 10, vigilance: 5, burden: -10, despair: -8, pride: -6 } as const

import { useGameStore } from '../store/gameStore'
import { getIdentityVisual } from '../systems/identitySystem'
import { hasFullArmor } from '../systems/sacredArmorSystem'
import { getActiveCompanions } from '../systems/companionSystem'
import { getNpcById, ARMOR_SLOT_ORDER } from '../lib/content'

/** Compact top-left strip: identity stage, armor progress, active companions. */
export function StatusStrip() {
  const gs = useGameStore((s) => s.gameState)
  const visual = getIdentityVisual(gs)
  const armorCount = ARMOR_SLOT_ORDER.filter((s) => !!gs.inventory.equipped[s]).length
  const companions = getActiveCompanions(gs)

  return (
    <div className="fixed top-4 left-4 z-20 flex flex-col gap-2 pointer-events-none">
      <div className="flex items-center gap-2 px-3 py-1.5 bg-black/45 rounded-lg border border-white/10">
        <span className="inline-block w-3 h-3 rounded-full" style={{ background: visual.robeColor, boxShadow: `0 0 ${6 + visual.glow * 14}px ${visual.robeColor}` }} />
        <span className="text-sm font-semibold">{visual.labelCN}</span>
      </div>
      <div className="px-3 py-1.5 bg-black/45 rounded-lg border border-white/10 text-xs">
        <span className={hasFullArmor(gs) ? 'text-amber-300 font-bold' : 'opacity-80'}>
          军装 {armorCount}/6 {hasFullArmor(gs) ? '· 全副穿戴' : ''}
        </span>
      </div>
      {companions.length > 0 && (
        <div className="px-3 py-1.5 bg-black/45 rounded-lg border border-white/10 text-xs">
          同行：{companions.map((c) => getNpcById(c.npcId)?.nameCN ?? c.npcId).join('、')}
        </div>
      )}
    </div>
  )
}

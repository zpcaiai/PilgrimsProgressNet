import { useGameStore } from '../../store/gameStore'
import { NPCMarker } from './NPCMarker'

// Visual identity for companions that can walk with the pilgrim (Batch 5+).
const COMPANION_LOOK: Record<string, { name: string; color: string }> = {
  faithful: { name: '忠信 Faithful', color: '#caa86a' },
  hopeful: { name: '盼望 Hopeful', color: '#7fd0e0' },
  pliable: { name: '易迁 Pliable', color: '#9a9a7a' },
}

/**
 * Renders every currently-active companion as a marker near the pilgrim, so the
 * party visibly grows (Faithful in the valley/fair, Hopeful after the martyrdom).
 */
export function CompanionParty({
  anchors = [[-2.6, 0, 9], [2.6, 0, 9], [-4.6, 0, 9]],
  onTalk,
}: {
  anchors?: [number, number, number][]
  onTalk?: (npcId: string) => void
}) {
  const companions = useGameStore((s) => s.gameState.companions)
  const active = companions.filter((c) => c.isActive)
  return (
    <>
      {active.map((c, i) => {
        const look = COMPANION_LOOK[c.npcId] ?? { name: c.npcId, color: '#aaaaaa' }
        return (
          <NPCMarker
            key={c.npcId}
            name={look.name}
            color={look.color}
            position={anchors[i % anchors.length]}
            onTalk={() => onTalk?.(c.npcId)}
            solid={false}
          />
        )
      })}
    </>
  )
}

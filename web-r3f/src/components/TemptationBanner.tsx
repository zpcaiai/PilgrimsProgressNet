import { useGameStore } from '../store/gameStore'
import { useUiStore } from '../store/uiStore'
import { getTemptationsForScene } from '../lib/content'
import {
  triggerTemptation, resolveTemptation, canResistTemptation, temptationOutcomeMessage,
} from '../systems/temptationSystem'

/** Surfaces scene temptations: Face → (Resist / Yield). Resolved ones are flagged. */
export function TemptationBanner({ sceneId }: { sceneId: string }) {
  const gs = useGameStore((s) => s.gameState)
  const mutate = useGameStore((s) => s.mutate)
  const setFlag = useGameStore((s) => s.setFlag)
  const showToast = useUiStore((s) => s.showToast)

  const sceneTemptations = getTemptationsForScene(sceneId)
  const active = sceneTemptations.find((t) => gs.activeTemptations.includes(t.id))
  const pending = sceneTemptations.find(
    (t) => !gs.activeTemptations.includes(t.id) && !gs.storyFlags[`resolved_${t.id}`],
  )

  if (!active && !pending) return null

  if (active) {
    const canResist = canResistTemptation(gs, active)
    const finish = (resisted: boolean) => {
      mutate((s) => resolveTemptation(s, active.id, resisted))
      setFlag(`resolved_${active.id}`)
      showToast(temptationOutcomeMessage(active, resisted))
    }
    return (
      <div className="fixed top-24 left-1/2 -translate-x-1/2 z-30 w-[480px] max-w-[92vw] bg-rose-950/90 border border-rose-400/40 rounded-xl p-4">
        <div className="text-[11px] uppercase tracking-wider text-rose-300/80 mb-1">试探 · {active.type}</div>
        <div className="font-semibold mb-1">{active.titleCN}</div>
        <p className="text-xs opacity-80 mb-3 leading-relaxed">{active.descriptionCN}</p>
        <div className="flex gap-2">
          <button
            disabled={!canResist}
            className={`px-3 py-1.5 text-sm rounded ${canResist ? 'bg-sky-500/40 hover:bg-sky-500/60' : 'bg-white/5 opacity-40 cursor-not-allowed'}`}
            onClick={() => finish(true)}
          >
            凭信抵挡
          </button>
          <button className="px-3 py-1.5 text-sm rounded bg-white/10 hover:bg-white/20" onClick={() => finish(false)}>屈服</button>
        </div>
        {!canResist && <p className="text-[11px] opacity-60 mt-2">尚不能抵挡——需要更多信心、相应的物品或军装。</p>}
      </div>
    )
  }

  return (
    <div className="fixed top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-amber-950/85 border border-amber-400/40 rounded-xl">
      <button className="text-sm" onClick={() => mutate((s) => triggerTemptation(s, pending!.id))}>
        ⚠ 面前有试探：「{pending!.titleCN}」— 点击面对
      </button>
    </div>
  )
}

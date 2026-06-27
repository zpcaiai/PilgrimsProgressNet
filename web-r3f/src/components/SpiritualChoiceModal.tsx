import { useState } from 'react'
import { useGameStore } from '../store/gameStore'
import { getChoiceById } from '../lib/content'
import { applySpiritualChoice } from '../systems/spiritualChoiceSystem'

export function SpiritualChoiceModal({ choiceId, onClose }: { choiceId: string; onClose: () => void }) {
  const mutate = useGameStore((s) => s.mutate)
  const choice = getChoiceById(choiceId)
  const [consequence, setConsequence] = useState<string | null>(null)
  if (!choice) return null

  const pick = (optionId: string) => {
    const result = applySpiritualChoice(useGameStore.getState().gameState, choiceId, optionId)
    mutate(() => result.state)
    setConsequence(result.consequence)
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/60">
      <div className="w-[560px] max-w-[92vw] bg-indigo-950/95 border border-indigo-400/30 rounded-2xl p-5">
        <div className="text-[11px] uppercase tracking-wider text-indigo-300/80 mb-1">属灵抉择</div>
        <h2 className="text-base font-semibold mb-4 leading-relaxed">{choice.promptCN}</h2>

        {consequence === null ? (
          <div className="flex flex-col gap-2">
            {choice.options.map((o) => (
              <button
                key={o.id}
                className="text-left px-4 py-3 bg-white/5 hover:bg-white/15 rounded-lg border border-white/10"
                onClick={() => pick(o.id)}
              >
                {o.textCN}
              </button>
            ))}
          </div>
        ) : (
          <div>
            <p className="text-sm text-indigo-100/90 mb-4 leading-relaxed">{consequence}</p>
            <button className="px-4 py-2 bg-emerald-500/40 hover:bg-emerald-500/60 rounded-lg" onClick={onClose}>继续</button>
          </div>
        )}
      </div>
    </div>
  )
}

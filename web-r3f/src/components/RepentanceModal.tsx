import { useState } from 'react'
import { useGameStore } from '../store/gameStore'
import { getRepentanceById } from '../lib/content'
import { applyRepentance } from '../systems/repentanceSystem'

export function RepentanceModal({ eventId, onClose }: { eventId: string; onClose: () => void }) {
  const mutate = useGameStore((s) => s.mutate)
  const ev = getRepentanceById(eventId)
  const [graceMsg, setGraceMsg] = useState<string | null>(null)
  if (!ev) return null

  const confess = (optionId: string) => {
    mutate((s) => applyRepentance(s, eventId, optionId))
    setGraceMsg(ev.graceOutcome.messageCN)
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/70">
      <div className="w-[560px] max-w-[92vw] bg-stone-900/95 border border-amber-400/30 rounded-2xl p-6">
        <div className="text-[11px] uppercase tracking-wider text-amber-300/80 mb-1">悔改 · 恩典</div>
        <h2 className="text-base font-semibold mb-4 leading-relaxed">{ev.titleCN}</h2>

        {graceMsg === null ? (
          <>
            <p className="text-sm opacity-85 mb-4 leading-relaxed">{ev.promptCN}</p>
            <div className="flex flex-col gap-2">
              {ev.confessionOptions.map((o) => (
                <button
                  key={o.id}
                  className="text-left px-4 py-3 bg-white/5 hover:bg-white/15 rounded-lg border border-white/10"
                  onClick={() => confess(o.id)}
                >
                  {o.textCN}
                </button>
              ))}
            </div>
          </>
        ) : (
          <div>
            <p className="text-sm text-amber-100/90 mb-4 leading-relaxed">{graceMsg}</p>
            <button className="px-4 py-2 bg-emerald-500/40 hover:bg-emerald-500/60 rounded-lg" onClick={onClose}>得力，继续前行</button>
          </div>
        )}
      </div>
    </div>
  )
}

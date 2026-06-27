import { useState } from 'react'
import { getChapelById, PRAY_EFFECTS, REPENT_EFFECTS } from '../lib/content'
import { useGameStore } from '../store/gameStore'

export function ChapelPanel({ chapelId, onClose }: { chapelId: string; onClose: () => void }) {
  const chapel = getChapelById(chapelId)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const visitChapel = useGameStore((s) => s.visitChapel)
  const [msg, setMsg] = useState<string | null>(null)
  if (!chapel) return null

  function pray() {
    applyEffects(PRAY_EFFECTS)
    visitChapel(chapel!.id)
    setMsg('你祷告，得了安静与力量。（信心 +8 · 盼望 +5 · 惧怕 −4）')
  }
  function repent() {
    applyEffects(REPENT_EFFECTS)
    visitChapel(chapel!.id)
    setMsg('你承认、放下、回转。重担减轻了。（谦卑 +10 · 重担 −10 · 绝望 −8）')
  }

  return (
    <div className="fixed inset-0 grid place-items-center bg-black/50" onClick={onClose}>
      <div className="w-[min(560px,92vw)] bg-neutral-900 border border-amber-300/30 rounded-2xl p-6" onClick={(e) => e.stopPropagation()}>
        <div className="text-amber-200 text-sm">✝ 小教堂 · {chapel.type}</div>
        <p className="mt-2 italic text-lg leading-relaxed">“{chapel.verseText}”</p>
        {chapel.unlocksQuestHint && <p className="mt-2 text-sm opacity-70">{chapel.unlocksQuestHint}</p>}
        {msg && <p className="mt-3 text-emerald-300">{msg}</p>}
        <div className="mt-5 flex gap-2 flex-wrap">
          <button className="px-4 py-2 bg-sky-500/30 hover:bg-sky-500/50 rounded-lg" onClick={pray}>[E] 祷告 Pray</button>
          <button className="px-4 py-2 bg-amber-500/30 hover:bg-amber-500/50 rounded-lg" onClick={repent}>[R] 悔改 Repent</button>
          <button className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg ml-auto" onClick={onClose}>离开</button>
        </div>
      </div>
    </div>
  )
}

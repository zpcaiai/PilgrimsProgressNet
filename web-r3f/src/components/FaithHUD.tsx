import { useGameStore } from '../store/gameStore'
import type { SpiritualStats } from '../types'

function StatBar({ label, value, inverse }: { label: string; value: number; inverse?: boolean }) {
  const pct = Math.max(0, Math.min(100, value))
  const good = inverse ? pct < 35 : pct > 60
  const mid = pct >= 35 && pct <= 60
  const color = good ? 'bg-emerald-400' : mid ? 'bg-amber-400' : 'bg-rose-500'
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className="w-12 shrink-0 text-right opacity-80">{label}</span>
      <div className="h-2 w-28 rounded bg-white/15 overflow-hidden">
        <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
      </div>
      <span className="w-6 tabular-nums opacity-60">{Math.round(value)}</span>
    </div>
  )
}

const ROWS: { key: keyof SpiritualStats; label: string; inverse?: boolean }[] = [
  { key: 'faith', label: '信心' },
  { key: 'hope', label: '盼望' },
  { key: 'vigilance', label: '警醒' },
  { key: 'humility', label: '谦卑' },
  { key: 'burden', label: '重担', inverse: true },
  { key: 'doubt', label: '疑惑', inverse: true },
  { key: 'fear', label: '惧怕', inverse: true },
]

export function FaithHUD() {
  const stats = useGameStore((s) => s.gameState.spiritualStats)
  const stage = useGameStore((s) => s.gameState.player.identityStage)
  return (
    <div className="fixed top-4 left-4 bg-black/60 backdrop-blur p-3 rounded-xl space-y-1 select-none">
      <div className="text-xs font-bold mb-1 opacity-90">天路客 · {stage}</div>
      {ROWS.map((r) => <StatBar key={r.key} label={r.label} value={stats[r.key]} inverse={r.inverse} />)}
    </div>
  )
}

import { useCombatStore } from '../store/combatStore'

/** The Apollyon fight HUD — boss health, the pilgrim's resolve, and big block /
 * strike buttons (driven by the scene via combatStore; mobile-friendly). */
export function CombatOverlay() {
  const active = useCombatStore((s) => s.active)
  const st = useCombatStore((s) => s.state)
  const h = useCombatStore((s) => s.handlers)
  if (!active || !st || st.phase === 'won') return null

  const boss = Math.max(0, Math.min(100, st.bossHp))
  const resolve = Math.max(0, Math.min(100, st.resolve))

  return (
    <div className="fixed left-1/2 -translate-x-1/2 bottom-20 z-40 w-[min(560px,94vw)] bg-black/70 border border-rose-400/30 rounded-2xl p-3">
      {/* Apollyon health */}
      <div className="flex items-center gap-2 text-xs mb-1">
        <span className="w-16 shrink-0 text-rose-300">亚玻伦</span>
        <div className="flex-1 h-2.5 bg-white/10 rounded"><div className="h-2.5 rounded bg-gradient-to-r from-rose-600 to-rose-400" style={{ width: `${boss}%` }} /></div>
      </div>
      {/* pilgrim resolve */}
      <div className="flex items-center gap-2 text-xs mb-2">
        <span className="w-16 shrink-0 text-sky-300">心志</span>
        <div className="flex-1 h-2.5 bg-white/10 rounded"><div className="h-2.5 rounded bg-gradient-to-r from-sky-500 to-emerald-300" style={{ width: `${resolve}%` }} /></div>
      </div>

      {st.phase === 'intro' && (
        <button className="w-full py-2.5 bg-rose-500/40 hover:bg-rose-500/60 rounded-lg font-bold" onClick={() => h.onStart?.()}>
          披甲迎战亚玻伦 ▸
        </button>
      )}

      {(st.phase === 'telegraph' || st.phase === 'riposte') && (
        <>
          <div className="text-center text-[11px] mb-2 opacity-80">
            {st.phase === 'telegraph'
              ? (st.guard ? '🛡 信德的盾已举起，挡住火箭' : '⚠ 亚玻伦发出火箭——快举起信德的盾！')
              : '⚔ 趁势用圣灵的宝剑还击！'}
          </div>
          <div className="flex gap-2">
            <button
              disabled={st.phase !== 'telegraph'}
              className={`flex-1 py-2.5 rounded-lg font-bold ${st.phase === 'telegraph' ? (st.guard ? 'bg-amber-400/50' : 'bg-sky-500/40 hover:bg-sky-500/60') : 'bg-white/5 opacity-40'}`}
              onClick={() => h.onGuard?.()}
            >
              🛡 举盾
            </button>
            <button
              disabled={st.phase !== 'riposte'}
              className={`flex-1 py-2.5 rounded-lg font-bold ${st.phase === 'riposte' ? 'bg-rose-500/50 hover:bg-rose-500/70' : 'bg-white/5 opacity-40'}`}
              onClick={() => h.onStrike?.()}
            >
              ⚔ 挥剑
            </button>
          </div>
        </>
      )}
    </div>
  )
}

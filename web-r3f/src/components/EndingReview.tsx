import { useGameStore } from '../store/gameStore'
import { buildEndingSummary } from '../systems/endingSystem'

/**
 * The finale screen, shown once the pilgrim enters the Celestial City — a review
 * of the whole journey, with New Game+ and a return to the menu.
 */
export function EndingReview({ onExitToMenu }: { onExitToMenu: () => void }) {
  const gs = useGameStore((s) => s.gameState)
  const newGamePlus = useGameStore((s) => s.newGamePlus)
  const r = buildEndingSummary(gs)

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-auto">
      <div className="w-[min(820px,96vw)] my-6 bg-gradient-to-b from-amber-950/95 to-stone-950/95 border border-amber-300/30 rounded-2xl p-6 shadow-2xl">
        <div className="text-center">
          <div className="text-amber-200 text-3xl font-bold tracking-wide">天路完成 · 进入天城</div>
          <div className="mt-1 opacity-80">“你这又良善又忠心的仆人，可以进来享受你主人的快乐。”</div>
          <div className="mt-3 inline-flex items-center gap-3 px-4 py-1.5 bg-amber-400/15 rounded-full">
            <span className="text-amber-200 font-semibold">评定：{r.rankCN}</span>
            <span className="opacity-60">·</span>
            <span>旅程分数 {r.score}</span>
            <span className="opacity-60">·</span>
            <span>{r.chaptersCompleted}/{r.totalChapters} 章</span>
          </div>
        </div>

        <div className="grid md:grid-cols-2 gap-5 mt-6">
          <div>
            <div className="text-sm uppercase tracking-wider text-amber-300/70 mb-2">旅程里程碑</div>
            <ul className="space-y-1.5">
              {r.milestones.map((m) => (
                <li key={m.id} className="flex items-center gap-2 text-sm">
                  <span className={m.achieved ? 'text-emerald-300' : 'text-white/30'}>{m.achieved ? '✓' : '○'}</span>
                  <span className={m.achieved ? '' : 'opacity-45'}>{m.labelCN}</span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <div className="text-sm uppercase tracking-wider text-amber-300/70 mb-2">属灵品格</div>
            <div className="space-y-1.5">
              {r.virtues.map((v) => (
                <div key={v.key} className="flex items-center gap-2 text-xs">
                  <span className="w-10 shrink-0 opacity-80">{v.labelCN}</span>
                  <div className="flex-1 h-2 bg-white/10 rounded">
                    <div className="h-2 rounded bg-gradient-to-r from-amber-400 to-emerald-300" style={{ width: `${Math.min(100, v.value)}%` }} />
                  </div>
                  <span className="w-7 text-right opacity-70">{v.value}</span>
                </div>
              ))}
            </div>

            <div className="mt-4 text-sm uppercase tracking-wider text-amber-300/70 mb-2">一路同行</div>
            <div className="text-sm opacity-90">{r.companionsCN.length ? r.companionsCN.join('、') : '独自走完'}</div>
            <div className="mt-3 text-sm uppercase tracking-wider text-amber-300/70 mb-2">随身信物</div>
            <div className="text-sm opacity-90">{r.keepsakesCN.length ? r.keepsakesCN.join('、') : '—'}</div>
          </div>
        </div>

        <div className="mt-5 flex flex-wrap justify-center gap-6 text-sm border-t border-white/10 pt-4">
          <span>凭信抵挡试探 <b className="text-amber-200">{r.resistedTemptations}</b> 次</span>
          <span>小教堂祷告 <b className="text-amber-200">{r.chapelVisits}</b> 次</span>
          <span>悔改归正 <b className="text-amber-200">{r.repentedTimes}</b> 次</span>
        </div>

        <div className="mt-6 flex justify-center gap-3">
          <button
            className="px-5 py-2 bg-emerald-500/40 hover:bg-emerald-500/60 rounded-lg font-semibold"
            onClick={() => newGamePlus()}
          >
            重走天路（新的旅程 +）
          </button>
          <button className="px-5 py-2 bg-white/10 hover:bg-white/20 rounded-lg" onClick={onExitToMenu}>
            返回菜单
          </button>
        </div>
        <p className="text-center text-xs opacity-50 mt-3">「新的旅程 +」带着上一程的笃定重新起步（信心 / 盼望 / 警醒略有加增）。</p>
      </div>
    </div>
  )
}

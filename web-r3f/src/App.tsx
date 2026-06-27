import { useEffect, useState } from 'react'
import { ChapterSelect } from './components/ChapterSelect'
import { Game } from './game/Game'
import { useGameStore } from './store/gameStore'

export default function App() {
  const [mode, setMode] = useState<'menu' | 'game'>('menu')
  const goTo = useGameStore((s) => s.goTo)
  const loadGame = useGameStore((s) => s.loadGame)
  const resetGame = useGameStore((s) => s.resetGame)
  const hasSave = useGameStore((s) => s.hasSave)

  useEffect(() => { loadGame() }, [loadGame])

  function start(chapterId: string, sceneId: string) {
    goTo(chapterId, sceneId)
    setMode('game')
  }

  if (mode === 'game') return <Game onExitToMenu={() => setMode('menu')} />

  return (
    <div className="h-full w-full overflow-auto">
      <header className="pt-10 text-center">
        <h1 className="text-4xl font-bold text-amber-200 tracking-wide">天路历程 · Pilgrim's Road</h1>
        <p className="opacity-70 mt-2">十六章灵程 · 选择你的旅程</p>
        <div className="flex gap-3 justify-center mt-5">
          <button
            className="px-5 py-2 bg-emerald-500/40 hover:bg-emerald-500/60 rounded-lg font-semibold"
            onClick={() => { resetGame(); goTo('chapter_01', 'city_of_destruction'); setMode('game') }}
          >
            新游戏
          </button>
          {hasSave() && (
            <button
              className="px-5 py-2 bg-sky-500/40 hover:bg-sky-500/60 rounded-lg font-semibold"
              onClick={() => { loadGame(); setMode('game') }}
            >
              继续
            </button>
          )}
        </div>
        <p className="opacity-50 text-xs mt-3">全 16 章皆为完整可玩场景。抵达天城后可开启「新的旅程 +」。</p>
      </header>

      <ChapterSelect onStart={start} />
    </div>
  )
}

import { CHAPTERS } from '../lib/content'
import { useGameStore } from '../store/gameStore'

export function ChapterSelect({ onStart }: { onStart: (chapterId: string, sceneId: string) => void }) {
  const unlocked = useGameStore((s) => s.gameState.chapters.unlockedChapterIds)
  const completed = useGameStore((s) => s.gameState.chapters.completedChapterIds)
  return (
    <div className="w-full p-8">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 max-w-5xl mx-auto">
        {CHAPTERS.map((c) => {
          const isUnlocked = unlocked.includes(c.id)
          const isDone = completed.includes(c.id)
          return (
            <button
              key={c.id}
              disabled={!isUnlocked}
              onClick={() => onStart(c.id, c.mainSceneId)}
              className={`text-left p-4 rounded-xl border transition ${isUnlocked ? 'border-amber-300/40 bg-white/5 hover:bg-white/10' : 'border-white/10 bg-black/30 opacity-40 cursor-not-allowed'}`}
            >
              <div className="text-xs opacity-60">第 {c.order} 章 {isDone ? '· ✓' : isUnlocked ? '' : '· 🔒'}</div>
              <div className="font-bold mt-1">{c.titleCN}</div>
              <div className="text-xs opacity-70 mt-1 line-clamp-2">{c.theme}</div>
            </button>
          )
        })}
      </div>
    </div>
  )
}

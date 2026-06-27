import { useState } from 'react'
import type { Dialogue, DialogueChoice } from '../types'
import { useGameStore } from '../store/gameStore'

export function DialoguePanel({ dialogue, onClose }: { dialogue: Dialogue; onClose: () => void }) {
  const [i, setI] = useState(0)
  const [showChoices, setShowChoices] = useState(false)
  const [result, setResult] = useState<string | null>(null)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const recordChoice = useGameStore((s) => s.recordChoice)

  const line = dialogue.lines[i]
  const atEnd = i >= dialogue.lines.length - 1

  function next() {
    if (!atEnd) { setI(i + 1); return }
    if (dialogue.choices?.length) { setShowChoices(true); return }
    onClose()
  }

  function choose(c: DialogueChoice) {
    applyEffects(c.effects, c.setFlags, c.addItems)
    recordChoice(dialogue.chapterId, c.id, c.consequenceCN ?? '')
    setResult(c.consequenceCN ?? '（已记录你的选择。）')
  }

  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 w-[min(680px,92vw)] bg-black/85 backdrop-blur rounded-2xl p-5 shadow-2xl">
      {result ? (
        <>
          <p className="text-amber-200 leading-relaxed">{result}</p>
          <div className="mt-4 text-right">
            <button className="px-4 py-2 bg-white/15 hover:bg-white/25 rounded-lg" onClick={onClose}>继续</button>
          </div>
        </>
      ) : !showChoices ? (
        <>
          <div className="text-xs uppercase tracking-wide text-sky-300/80">{line.speaker}</div>
          <p className="mt-1 leading-relaxed text-lg">{line.textCN}</p>
          <div className="mt-4 text-right">
            <button className="px-4 py-2 bg-white/15 hover:bg-white/25 rounded-lg" onClick={next}>
              {atEnd && !dialogue.choices?.length ? '结束' : '▸'}
            </button>
          </div>
        </>
      ) : (
        <div className="space-y-2">
          {dialogue.choices!.map((c) => (
            <button key={c.id} onClick={() => choose(c)} className="block w-full text-left px-4 py-3 bg-white/10 hover:bg-white/20 rounded-lg">
              {c.textCN}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

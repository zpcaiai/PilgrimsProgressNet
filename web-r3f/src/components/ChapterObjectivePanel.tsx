export type Objective = { id: string; labelCN: string; completed: boolean }

export function ChapterObjectivePanel({ chapterTitle, objectives }: { chapterTitle: string; objectives: Objective[] }) {
  return (
    <div className="fixed top-4 right-4 bg-black/60 backdrop-blur p-4 rounded-xl w-72 select-none">
      <h2 className="text-base font-bold">{chapterTitle}</h2>
      <ul className="mt-2 space-y-1 text-sm">
        {objectives.map((o) => (
          <li key={o.id} className={o.completed ? 'opacity-50 line-through' : ''}>
            {o.completed ? '✓' : '○'} {o.labelCN}
          </li>
        ))}
      </ul>
    </div>
  )
}

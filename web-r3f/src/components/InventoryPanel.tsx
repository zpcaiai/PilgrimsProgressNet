import { useGameStore } from '../store/gameStore'
import { useUiStore } from '../store/uiStore'
import { getItemById, SACRED_ARMOR, ARMOR_SLOT_ORDER } from '../lib/content'
import { useItem } from '../systems/inventorySystem'
import type { ItemRarity } from '../types'

const RARITY: Record<ItemRarity, { cn: string; cls: string }> = {
  common: { cn: '普通', cls: 'text-gray-300 border-gray-500/40' },
  important: { cn: '重要', cls: 'text-sky-300 border-sky-500/40' },
  sacred: { cn: '圣洁', cls: 'text-amber-300 border-amber-500/50' },
  dangerous: { cn: '危险', cls: 'text-rose-300 border-rose-500/50' },
  unique: { cn: '独一', cls: 'text-fuchsia-300 border-fuchsia-500/50' },
}

export function InventoryPanel({ onClose }: { onClose: () => void }) {
  const gs = useGameStore((s) => s.gameState)
  const mutate = useGameStore((s) => s.mutate)
  const showToast = useUiStore((s) => s.showToast)

  const items = gs.inventory.items.map(getItemById).filter((i): i is NonNullable<typeof i> => !!i)

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/60" onClick={onClose}>
      <div className="w-[680px] max-w-[92vw] max-h-[82vh] overflow-auto bg-stone-900/95 border border-white/10 rounded-2xl p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-bold">行囊 · Inventory</h2>
          <button className="px-2 py-1 text-sm bg-white/10 hover:bg-white/20 rounded" onClick={onClose}>✕</button>
        </div>

        <h3 className="text-sm opacity-70 mb-2">物品（{items.length}）</h3>
        {items.length === 0 && <p className="text-sm opacity-50 mb-3">行囊空空——一路领受的恩典会出现在这里。</p>}
        <div className="grid grid-cols-2 gap-2 mb-5">
          {items.map((item) => (
            <div key={item.id} className={`border rounded-lg p-3 bg-white/5 ${RARITY[item.rarity].cls}`}>
              <div className="flex items-center justify-between">
                <span className="font-semibold">{item.nameCN}</span>
                <span className="text-[10px] px-1.5 py-0.5 rounded border opacity-80">{RARITY[item.rarity].cn}</span>
              </div>
              <p className="text-xs opacity-70 mt-1 leading-snug">{item.descriptionCN}</p>
              {item.symbolMeaningCN && <p className="text-[11px] italic opacity-50 mt-1">寓意：{item.symbolMeaningCN}</p>}
              {item.usable && (
                <button
                  className="mt-2 px-2 py-1 text-xs bg-amber-500/25 hover:bg-amber-500/45 rounded"
                  onClick={() => { mutate((s) => useItem(s, item.id)); showToast(`使用了「${item.nameCN}」`) }}
                >
                  使用
                </button>
              )}
            </div>
          ))}
        </div>

        <h3 className="text-sm opacity-70 mb-2">神圣军装 · Armor of God（弗 6）</h3>
        <div className="grid grid-cols-3 gap-2">
          {ARMOR_SLOT_ORDER.map((slot) => {
            const equippedId = gs.inventory.equipped[slot]
            const piece = SACRED_ARMOR.find((a) => a.slot === slot)
            const on = !!equippedId
            return (
              <div key={slot} className={`border rounded-lg p-2 text-xs ${on ? 'border-amber-400/60 bg-amber-400/10' : 'border-white/10 bg-white/5 opacity-60'}`}>
                <div className="font-semibold">{piece?.nameCN ?? slot}</div>
                <div className="opacity-70">{on ? '已穿戴' : '未得'}</div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById, SACRED_ARMOR } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { grantFullArmor } from '../systems/sacredArmorSystem'

function ArmorStands({ equippedSlots }: { equippedSlots: string[] }) {
  return (
    <>
      {SACRED_ARMOR.map((a, i) => {
        const x = -7.5 + i * 3
        const on = equippedSlots.includes(a.slot)
        return (
          <group key={a.id} position={[x, 0, -9]}>
            <Collider circle={[x, -9, 0.55]} />
            <mesh position={[0, 0.6, 0]} castShadow><cylinderGeometry args={[0.4, 0.5, 1.2, 12]} /><meshStandardMaterial color="#4a4038" /></mesh>
            <mesh position={[0, 1.6, 0]} castShadow><boxGeometry args={[0.8, 0.9, 0.4]} /><meshStandardMaterial color={on ? '#d4af37' : '#9aa0a6'} metalness={0.8} roughness={0.3} emissive={on ? '#d4af37' : '#000'} emissiveIntensity={on ? 0.3 : 0} /></mesh>
            <Html center position={[0, 2.5, 0]} distanceFactor={15}><div className="px-1.5 py-0.5 text-[10px] bg-black/60 rounded whitespace-nowrap pointer-events-none">{a.nameCN}{on ? ' ✓' : ''}</div></Html>
          </group>
        )
      })}
    </>
  )
}

export function Chapter07Armory() {
  const openChapel = useUiStore((s) => s.openChapel)
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const mutate = useGameStore((s) => s.mutate)
  const equipped = useGameStore((s) => s.gameState.inventory.equipped)
  const received = useGameStore((s) => !!s.gameState.storyFlags.received_full_armor)
  const chapel = getChapelById('chapel_armory_hall')
  const equippedSlots = Object.keys(equipped).filter((k) => (equipped as Record<string, string | undefined>)[k])

  const takeArmor = () => {
    mutate((s) => grantFullArmor(s))
    showToast('你逐件披戴神所赐的全副军装（弗 6）——真理带、护心镜、福音鞋、信德盾、救恩盔、圣灵剑。')
  }

  return (
    <group>
      <fog attach="fog" args={['#181a1e', 30, 80]} />
      <NaturalGround detail size={[28, 30]} color="#3a3d44" amp={0} roughness={0.85} />
      <mesh position={[0, 4, -13]} receiveShadow><boxGeometry args={[28, 8, 0.5]} /><meshStandardMaterial color="#464a52" roughness={0.82} metalness={0.08} /></mesh>
      <Collider box={[0, -13, 28, 0.5]} />
      {/* hanging cloth banners flanking the hall */}
      {[-9, 9].map((x) => (
        <mesh key={x} position={[x, 5, -12.66]} castShadow><planeGeometry args={[2, 5]} /><meshStandardMaterial color="#2a3a6a" roughness={0.9} metalness={0} side={2} /></mesh>
      ))}
      <Collider circle={[0, -3, 1.6]} />{/* central pedestal */}

      <ArmorStands equippedSlots={equippedSlots} />

      {/* central pedestal: receive the full armor */}
      <group position={[0, 0, -3]} onClick={(e) => { e.stopPropagation(); if (!received) takeArmor() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 0.5, 0]} castShadow><cylinderGeometry args={[1.4, 1.6, 1, 24]} /><meshStandardMaterial color={received ? '#b9941f' : '#6a6a72'} metalness={0.7} roughness={0.35} /></mesh>
        <pointLight position={[0, 2, 0]} intensity={received ? 14 : 7} distance={16} color="#ffe6a0" />
        <Html center position={[0, 2.2, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-xs bg-black/65 rounded whitespace-nowrap pointer-events-none">{received ? '✓ 已披戴全副军装' : '领取全副军装（点击）'}</div></Html>
      </group>

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}
      <NPCMarker name="Watchful 警醒" color="#4a6a8a" position={[5, 0, -5]} onTalk={() => openDialogue('dialogue_watchful_gate')} />

      <hemisphereLight args={['#aab0b8', '#1a1c20', 0.5]} />
      <Player start={[0, 0, 8]} />
    </group>
  )
}

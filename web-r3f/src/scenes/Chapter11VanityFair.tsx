import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { CompanionParty } from '../components/three/CompanionParty'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

/** A gaudy market stall hawking the world's wares. */
function Booth({ x, z, awning, label, hawk, onHawk }: { x: number; z: number; awning: string; label: string; hawk: string; onHawk: (m: string) => void }) {
  return (
    <group position={[x, 0, z]} onClick={(e) => { e.stopPropagation(); onHawk(hawk) }}
      onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
      <Collider box={[x, z - 0.5, 2.2, 0.5]} />{/* stall counter blocks the way */}
      <mesh position={[-1.1, 1, 0]} castShadow><cylinderGeometry args={[0.1, 0.1, 2, 8]} /><meshStandardMaterial color="#5a4632" roughness={0.9} metalness={0} /></mesh>
      <mesh position={[1.1, 1, 0]} castShadow><cylinderGeometry args={[0.1, 0.1, 2, 8]} /><meshStandardMaterial color="#5a4632" roughness={0.9} metalness={0} /></mesh>
      <mesh position={[0, 2.1, 0]} rotation={[0.35, 0, 0]} castShadow><boxGeometry args={[2.6, 0.1, 1.4]} /><meshStandardMaterial color={awning} roughness={0.92} metalness={0} side={2} /></mesh>
      <mesh position={[0, 0.9, -0.5]} castShadow receiveShadow><boxGeometry args={[2.2, 0.7, 0.4]} /><meshStandardMaterial color="#7a5a3a" roughness={0.85} metalness={0} /></mesh>
      <Html center position={[0, 2.7, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">{label}</div></Html>
    </group>
  )
}

/** Vanity masks on a pole — flattery, hypocrisy, applause. */
function MaskPole({ x, z }: { x: number; z: number }) {
  return (
    <group position={[x, 0, z]}>
      <mesh position={[0, 1.4, 0]} castShadow><cylinderGeometry args={[0.07, 0.07, 2.8, 8]} /><meshStandardMaterial color="#4a3a2a" roughness={0.9} metalness={0} /></mesh>
      {['#d4af37', '#b08fd0', '#d06a6a'].map((c, i) => (
        <mesh key={i} position={[0, 2.0 + i * 0.5, 0.1]} rotation={[0, 0, i * 0.4]} castShadow><boxGeometry args={[0.5, 0.6, 0.08]} /><meshStandardMaterial color={c} metalness={i === 0 ? 0.85 : 0.2} roughness={i === 0 ? 0.3 : 0.6} /></mesh>
      ))}
    </group>
  )
}

export function Chapter11VanityFair() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const refused = useGameStore((s) => !!s.gameState.storyFlags.refused_vanity_fame)
  const chapel = getChapelById('chapel_hidden_vanity_fair')

  const refuse = () => {
    if (refused) return
    applyEffects({ witness: 14, courage: 8, worldliness: -10, humility: 6, pride: -6 }, ['refused_vanity_fame', 'refused_vanity'])
    showToast('“我只买真理。”众人嘲笑、推搡，你与忠信却不为所动——你的见证更显明亮。')
  }

  return (
    <group>
      <fog attach="fog" args={['#241a10', 28, 86]} />
      <NaturalGround detail size={[60, 70]} color="#4a3a26" />
      {/* market street stones */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, -12]} receiveShadow><planeGeometry args={[6, 44]} /><meshStandardMaterial color="#6a553a" /></mesh>

      {/* booths line both sides of the fair */}
      <Booth x={-5} z={-6} awning="#b23a3a" label="名声 · 徽章" hawk="叫卖者：戴上这枚名声徽章，全城都要称赞你！" onHawk={showToast} />
      <Booth x={5} z={-8} awning="#8a4fb0" label="地位 · 头衔" hawk="叫卖者：买个头衔吧，从此高人一等！" onHawk={showToast} />
      <Booth x={-5.5} z={-14} awning="#caa23a" label="银钱 · 享乐" hawk="叫卖者：少讲一点真理，就能换来这袋银子。" onHawk={showToast} />
      <Booth x={5.2} z={-16} awning="#3a8a6a" label="虚华 · 珍奇" hawk="叫卖者：天下奇货，应有尽有，只要你肯出价。" onHawk={showToast} />
      <MaskPole x={-2.6} z={-10} /><MaskPole x={2.6} z={-12} />

      {/* gold lamps */}
      {[-3, 3].map((x) => (
        <group key={x} position={[x, 0, -4]}>
          <mesh position={[0, 1.6, 0]} castShadow><cylinderGeometry args={[0.06, 0.06, 3.2, 8]} /><meshStandardMaterial color="#7a6a3a" /></mesh>
          <mesh position={[0, 3.3, 0]}><sphereGeometry args={[0.22, 12, 12]} /><meshStandardMaterial color="#ffe6a0" emissive="#ffcf6a" emissiveIntensity={1.6} /></mesh>
          <pointLight position={[0, 3.3, 0]} intensity={5} distance={12} color="#ffd98a" />
        </group>
      ))}

      {/* jeering crowd */}
      {[[-7, -2], [7, -3], [-7.5, -10], [7.4, -12], [-8, -18]].map(([x, z], i) => (
        <group key={i}>
          <Collider circle={[x, z, 0.45]} />
          <mesh position={[x, 0.8, z]} castShadow><capsuleGeometry args={[0.28, 0.8, 4, 8]} /><meshStandardMaterial color={['#6a5a4a', '#7a6a5a', '#5a5a6a'][i % 3]} /></mesh>
        </group>
      ))}

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* the pilgrim's stand: buy only the truth */}
      <group position={[0, 0, -20]} onClick={(e) => { e.stopPropagation(); refuse() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 0.5, 0]} castShadow><cylinderGeometry args={[1, 1.1, 1, 20]} /><meshStandardMaterial color={refused ? '#cdb46a' : '#5a5a5a'} metalness={0.4} roughness={0.5} /></mesh>
        <Html center position={[0, 1.9, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">{refused ? '✓ 我只买真理' : '“我只买真理”（点击拒绝叫卖）'}</div></Html>
      </group>

      {/* Faithful walks alongside; jeered with you but unmoved */}
      <CompanionParty onTalk={() => showToast('忠信与你并肩穿过虚华市，不动声色地拒绝一切叫卖。')} />
      <NPCMarker name="评判官 Judge(注视)" color="#5a4a4a" position={[-3, 0, -22]} onTalk={() => showToast('市中的官长盯着你们——拒绝买卖的人，在虚华市是要受审的。')} />

      <hemisphereLight args={['#c8b088', '#241a10', 0.55]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}

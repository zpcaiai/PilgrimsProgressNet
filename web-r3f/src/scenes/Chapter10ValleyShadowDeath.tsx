import { useEffect } from 'react'
import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { addCompanion, hasCompanion } from '../systems/companionSystem'

/** A dark pit / open grave flanking the narrow path. */
function Pit({ x, z }: { x: number; z: number }) {
  return (
    <mesh position={[x, 0.02, z]} rotation={[-Math.PI / 2, 0, 0]}>
      <circleGeometry args={[1.8, 18]} />
      <meshStandardMaterial color="#070608" />
    </mesh>
  )
}

export function Chapter10ValleyShadowDeath() {
  const openChapel = useUiStore((s) => s.openChapel)
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const mutate = useGameStore((s) => s.mutate)
  const gs = useGameStore((s) => s.gameState)
  const crossed = !!gs.storyFlags.crossed_shadow_valley
  const faithfulJoined = !!gs.storyFlags.faithful_joined
  const hasLantern = gs.inventory.items.includes('scripture_lantern')
  const chapel = getChapelById('chapel_shadow_valley')

  // Keep the companion array in sync once the meeting dialogue sets the flag.
  useEffect(() => {
    if (faithfulJoined && !hasCompanion(gs, 'faithful')) {
      mutate((s) => addCompanion(s, 'faithful', 'chapter_10'))
    }
  }, [faithfulJoined, gs, mutate])

  const pressOn = () => {
    if (crossed) return
    applyEffects({ faith: 8, courage: 8, vigilance: 6, fear: -8 }, ['crossed_shadow_valley'])
    showToast('你不偏左右，凭着祷告的微光一步一步走过死荫的幽谷。天将破晓。')
  }

  return (
    <group>
      <fog attach="fog" args={['#05060a', 8, 46]} />
      <NaturalGround detail size={[44, 140]} color="#0d0f14" />
      {/* sheer black walls */}
      <mesh position={[-9, 8, -24]} castShadow receiveShadow><boxGeometry args={[5, 16, 110]} /><meshStandardMaterial color="#070809" roughness={0.98} metalness={0} /></mesh>
      <mesh position={[9, 8, -24]} castShadow receiveShadow><boxGeometry args={[5, 16, 110]} /><meshStandardMaterial color="#070809" roughness={0.98} metalness={0} /></mesh>
      <Collider box={[-9, -24, 5, 110]} />
      <Collider box={[9, -24, 5, 110]} />

      {/* the narrow safe path down the middle (ditch on one side, quag on the other) */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, -20]} receiveShadow><planeGeometry args={[2.4, 70]} /><meshStandardMaterial color="#26221c" /></mesh>
      <Pit x={-3.2} z={-6} /><Pit x={3.2} z={-14} /><Pit x={-3.4} z={-24} /><Pit x={3.3} z={-32} />

      {/* lantern glow that lights the next step — brighter when the pilgrim carries the Scripture Lantern */}
      <pointLight position={[0, 2.2, 2]} intensity={hasLantern ? 9 : 3.2} distance={hasLantern ? 20 : 11} color="#ffd58a" />
      {hasLantern && (
        <mesh position={[0.7, 1.1, 5]}><sphereGeometry args={[0.16, 12, 12]} /><meshStandardMaterial color="#ffe6a0" emissive="#ffd070" emissiveIntensity={2.4} /></mesh>
      )}

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* press on through the dark */}
      <group position={[0, 0, -30]} onClick={(e) => { e.stopPropagation(); if (!crossed) pressOn() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 1.6, 0]}><boxGeometry args={[0.12, 1, 0.12]} /><meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={0.7} /></mesh>
        <mesh position={[0, 1.85, 0]}><boxGeometry args={[0.5, 0.12, 0.12]} /><meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={0.7} /></mesh>
        <Html center position={[0, 2.6, 0]} distanceFactor={18}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">{crossed ? '已走过幽谷' : '持守真道，一步步前行（点击）'}</div></Html>
      </group>

      {/* Faithful waits where the valley breaks into dawn — meeting him joins the party */}
      {crossed && (
        <NPCMarker name={faithfulJoined ? '忠信 Faithful（同行）' : '忠信 Faithful'} color="#caa86a" position={[1.6, 0, -34]} onTalk={() => openDialogue('dialogue_faithful_meeting')} />
      )}

      {crossed && <pointLight position={[2, 6, -40]} intensity={9} distance={40} color="#ffdca0" />}

      <hemisphereLight args={['#23262f', '#030304', 0.25]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}

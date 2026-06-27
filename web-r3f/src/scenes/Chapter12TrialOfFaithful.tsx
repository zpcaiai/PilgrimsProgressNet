import { useEffect, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { applyMutation } from '../systems/_apply'
import { addCompanion, hasCompanion, leaveCompanion } from '../systems/companionSystem'

/** Chariot of fire that carries Faithful from the stake up to the Celestial City. */
function ChariotOfFire({ active }: { active: boolean }) {
  const ref = useRef<THREE.Group>(null)
  useFrame((state) => {
    const g = ref.current
    if (!g) return
    const target = active ? 9 + ((state.clock.elapsedTime * 0.6) % 6) : 16
    g.position.y = THREE.MathUtils.lerp(g.position.y, active ? target : 22, 0.04)
    g.visible = g.position.y < 21
  })
  return (
    <group ref={ref} position={[0, 16, -12]} visible={active}>
      <mesh castShadow><boxGeometry args={[1.8, 0.9, 1.2]} /><meshStandardMaterial color="#ffe6a0" emissive="#ffcf6a" emissiveIntensity={1.4} /></mesh>
      <mesh position={[0, -0.5, 0.7]}><cylinderGeometry args={[0.4, 0.4, 0.16, 16]} /><meshStandardMaterial color="#caa23a" metalness={0.7} /></mesh>
      <mesh position={[0, -0.5, -0.7]}><cylinderGeometry args={[0.4, 0.4, 0.16, 16]} /><meshStandardMaterial color="#caa23a" metalness={0.7} /></mesh>
      <pointLight intensity={14} distance={26} color="#ffe6b0" />
      <Html center position={[0, 1.2, 0]} distanceFactor={20}><div className="px-2 py-0.5 text-[11px] bg-black/55 rounded whitespace-nowrap pointer-events-none">火焰战车 · 接忠信回家</div></Html>
    </group>
  )
}

/** The stake with faggots; glows alight once the martyrdom happens. */
function Pyre({ lit }: { lit: boolean }) {
  return (
    <group position={[0, 0, -12]}>
      <mesh position={[0, 1.4, 0]} castShadow><cylinderGeometry args={[0.12, 0.12, 2.8, 8]} /><meshStandardMaterial color="#4a3a2a" roughness={0.9} metalness={0} /></mesh>
      {[0, 1, 2, 3, 4].map((i) => (
        <mesh key={i} position={[Math.cos(i) * 0.5, 0.3, Math.sin(i) * 0.5]} rotation={[0, i, 0.2]} castShadow>
          <cylinderGeometry args={[0.08, 0.08, 1.1, 6]} /><meshStandardMaterial color="#6a4a2a" />
        </mesh>
      ))}
      {lit && (
        <>
          {[0, 1, 2].map((i) => (
            <mesh key={i} position={[(Math.random() - 0.5) * 0.8, 0.7 + i * 0.4, (Math.random() - 0.5) * 0.8]}><coneGeometry args={[0.3, 0.9, 8]} /><meshStandardMaterial color="#ff8a3a" emissive="#ff6a22" emissiveIntensity={2} /></mesh>
          ))}
          <pointLight position={[0, 1.4, 0]} intensity={10} distance={16} color="#ff7a3a" />
        </>
      )}
    </group>
  )
}

export function Chapter12TrialOfFaithful() {
  const openChapel = useUiStore((s) => s.openChapel)
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const mutate = useGameStore((s) => s.mutate)
  const gs = useGameStore((s) => s.gameState)
  const martyred = !!gs.storyFlags.faithful_martyred
  const hopefulJoined = !!gs.storyFlags.hopeful_joined
  const chapel = getChapelById('chapel_faithful_martyrdom')

  // Once the join dialogue fires, make sure Hopeful is in the active party.
  useEffect(() => {
    if (hopefulJoined && !hasCompanion(gs, 'hopeful')) {
      mutate((s) => addCompanion(s, 'hopeful', 'chapter_12'))
    }
  }, [hopefulJoined, gs, mutate])

  const standWithFaithful = () => {
    if (martyred) return
    mutate((s) => {
      const left = leaveCompanion(s, 'faithful', 'chapter_12', 'martyred')
      return applyMutation(left, {
        effects: { witness: 16, courage: 10, hope: 8, fear: -6, worldliness: -6 },
        setFlags: ['faithful_martyred', 'stood_with_faithful'],
        addItems: ['faithful_witness_token'],
      })
    })
    showToast('你公开站在忠信一边作见证。忠信至死忠心，火焰未能熄灭他的见证——火焰战车接他回天城去了。')
  }

  return (
    <group>
      <fog attach="fog" args={['#1a1410', 26, 84]} />
      <NaturalGround detail size={[44, 56]} color="#3a322a" amp={0} />
      {/* judge's bench + back wall of the court */}
      <mesh position={[0, 3.2, -18]} receiveShadow castShadow><boxGeometry args={[30, 7, 0.6]} /><meshStandardMaterial color="#46403a" roughness={0.92} metalness={0} /></mesh>
      <mesh position={[0, 1.4, -16]} castShadow receiveShadow><boxGeometry args={[6, 1.6, 1.6]} /><meshStandardMaterial color="#5a4a3a" roughness={0.85} metalness={0} /></mesh>
      <Collider box={[0, -18, 30, 0.6]} />
      <Collider box={[0, -16, 6, 1.6]} />{/* judge's bench */}
      <Html center position={[0, 2.7, -16]} distanceFactor={20}><div className="px-2 py-0.5 text-[11px] bg-black/55 rounded whitespace-nowrap pointer-events-none">虚华市法庭 · 审判忠信</div></Html>

      {/* the dock — Faithful stands trial until the martyrdom */}
      {!martyred && (
        <group position={[-2.6, 0, -8]}>
          <mesh position={[0, 0.9, 0]} castShadow><capsuleGeometry args={[0.3, 0.9, 4, 8]} /><meshStandardMaterial color="#caa86a" /></mesh>
          <mesh position={[0, 1.7, 0]} castShadow><sphereGeometry args={[0.24, 12, 12]} /><meshStandardMaterial color="#d8c6a8" /></mesh>
          {/* bars of the dock */}
          {[-0.7, -0.23, 0.23, 0.7].map((x) => (
            <mesh key={x} position={[x, 1, 0.6]}><cylinderGeometry args={[0.04, 0.04, 2, 6]} /><meshStandardMaterial color="#2a241e" metalness={0.5} roughness={0.5} /></mesh>
          ))}
          <Html center position={[0, 2.4, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">忠信 Faithful · 受审</div></Html>
        </group>
      )}

      <Pyre lit={martyred} />
      <ChariotOfFire active={martyred} />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* the pilgrim's witness: stand with Faithful */}
      {!martyred && (
        <group position={[2.6, 0, -6]} onClick={(e) => { e.stopPropagation(); standWithFaithful() }}
          onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
          <mesh position={[0, 0.5, 0]} castShadow receiveShadow><cylinderGeometry args={[0.9, 1, 1, 24]} /><meshStandardMaterial color="#7a6a4a" roughness={0.85} metalness={0} /></mesh>
          <Html center position={[0, 1.8, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">公开站在忠信一边（点击）</div></Html>
        </group>
      )}

      {/* Hopeful, born of the witness, rises to take Faithful's place */}
      {martyred && (
        <NPCMarker name={hopefulJoined ? '盼望 Hopeful（同行）' : '盼望 Hopeful'} color="#7fd0e0" position={[2.4, 0, -7]} onTalk={() => openDialogue('dialogue_hopeful_join')} />
      )}

      {martyred && (
        <Html center position={[0, 4.6, -6]} distanceFactor={24}>
          <div className="px-3 py-1.5 bg-black/70 rounded-lg text-center text-amber-200 whitespace-nowrap pointer-events-none">“你务要至死忠心，我就赐给你生命的冠冕。” · 殉道点燃了盼望</div>
        </Html>
      )}

      <hemisphereLight args={['#b09878', '#1a140e', 0.5]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}

import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

function Columns() {
  return (
    <>
      {[-6, -2, 2, 6].map((x) => (
        <group key={x}>
          <Collider circle={[x, -11, 0.6]} />
          <mesh position={[x, 3, -11]} castShadow receiveShadow><cylinderGeometry args={[0.46, 0.5, 6, 24]} /><meshStandardMaterial color="#d8d0c0" roughness={0.4} metalness={0.05} /></mesh>
          <mesh position={[x, 6.1, -11]} castShadow><boxGeometry args={[1.2, 0.3, 1.2]} /><meshStandardMaterial color="#cabfa6" roughness={0.45} /></mesh>
          <mesh position={[x, 0.15, -11]} castShadow><boxGeometry args={[1.3, 0.3, 1.3]} /><meshStandardMaterial color="#cabfa6" roughness={0.5} /></mesh>
        </group>
      ))}
    </>
  )
}

export function Chapter06HouseBeautiful() {
  const openChapel = useUiStore((s) => s.openChapel)
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const rested = useGameStore((s) => !!s.gameState.storyFlags.rested_house_beautiful)
  const chapel = getChapelById('chapel_house_beautiful')

  const rest = () => {
    applyEffects({ hope: 8, faith: 6, love: 6, fear: -4, vigilance: 4 }, ['rested_house_beautiful'])
    showToast('你在美宫的团契中安息，重新得力。')
  }

  return (
    <group>
      <fog attach="fog" args={['#1c1a22', 30, 80]} />
      <NaturalGround detail size={[24, 30]} color="#5b5468" amp={0} roughness={0.9} />
      <mesh position={[0, 3.5, -13]} receiveShadow><boxGeometry args={[24, 7, 0.5]} /><meshStandardMaterial color="#6b6378" roughness={0.85} metalness={0} /></mesh>
      <Collider box={[0, -13, 24, 0.5]} />
      {/* a deep crimson runner down the marble hall */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, -5]} receiveShadow><planeGeometry args={[3.2, 16]} /><meshStandardMaterial color="#5a2230" roughness={0.95} metalness={0} /></mesh>
      <Columns />

      {/* couch of rest */}
      <group position={[-4, 0, -3]} onClick={(e) => { e.stopPropagation(); if (!rested) rest() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 0.4, 0]} castShadow><boxGeometry args={[3, 0.6, 1.4]} /><meshStandardMaterial color={rested ? '#8a7fa0' : '#9a6a6a'} /></mesh>
        <mesh position={[-1.3, 0.9, 0]} castShadow><boxGeometry args={[0.4, 1, 1.4]} /><meshStandardMaterial color="#7a5a5a" /></mesh>
        <Html center position={[0, 1.6, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">{rested ? '已在此安息' : '安息之榻（点击休息）'}</div></Html>
      </group>

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      <NPCMarker name="Watchful 警醒" color="#4a6a8a" position={[4, 0, -6]} onTalk={() => openDialogue('dialogue_watchful_gate')} />
      <NPCMarker name="Piety 虔诚" color="#8a7a9a" position={[2, 0, -2]} onTalk={() => showToast('虔诚向你讲述这道路上历代忠心之人的见证。')} />
      <NPCMarker name="Charity 仁爱" color="#9a7a6a" position={[6, 0, -1]} onTalk={() => showToast('仁爱提醒你：要记念路上软弱的同伴。')} />

      <hemisphereLight args={['#b0a8c8', '#201c28', 0.55]} />
      <pointLight position={[0, 6, 2]} intensity={9} distance={26} color="#ffe6c0" />
      <Player start={[0, 0, 8]} />
    </group>
  )
}

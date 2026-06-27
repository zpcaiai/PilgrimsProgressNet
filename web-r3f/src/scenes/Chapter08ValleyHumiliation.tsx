import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock, Tree } from '../components/three/NatureKit'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

/** A distant silhouette of the bull-headed accuser — full encounter is Chapter 9. */
function ApollyonForeshadow() {
  return (
    <group position={[0, 0, -42]}>
      <mesh position={[0, 2.2, 0]} castShadow><boxGeometry args={[2.4, 4.4, 1.4]} /><meshStandardMaterial color="#1c1416" /></mesh>
      <mesh position={[0, 4.8, 0]} castShadow><boxGeometry args={[1.6, 1.4, 1.4]} /><meshStandardMaterial color="#241012" /></mesh>
      <mesh position={[-0.9, 5.4, 0.2]} rotation={[0, 0, 0.5]} castShadow><coneGeometry args={[0.22, 1.1, 8]} /><meshStandardMaterial color="#3a2a22" /></mesh>
      <mesh position={[0.9, 5.4, 0.2]} rotation={[0, 0, -0.5]} castShadow><coneGeometry args={[0.22, 1.1, 8]} /><meshStandardMaterial color="#3a2a22" /></mesh>
      <pointLight position={[0, 4.7, 1.2]} intensity={5} distance={14} color="#ff3a2a" />
      <Html center position={[0, 7, 0]} distanceFactor={20}><div className="px-2 py-0.5 text-[11px] bg-black/70 rounded whitespace-nowrap pointer-events-none">前方有控告者的气息（牛头鬼怪 · 第 9 章）</div></Html>
    </group>
  )
}

export function Chapter08ValleyHumiliation() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const humbled = useGameStore((s) => !!s.gameState.storyFlags.humbled_in_valley)
  const chapel = getChapelById('chapel_valley_humiliation')

  const humble = () => {
    applyEffects({ humility: 12, pride: -10, vigilance: 5, courage: 4 }, ['humbled_in_valley'])
    showToast('你俯首谦卑下行——不靠自己的力量，而靠所披戴的军装与那位赐恩的主。')
  }

  return (
    <group>
      <fog attach="fog" args={['#161a1c', 20, 78]} />
      <NaturalGround detail size={[60, 100]} color="#2a2e2c" />
      {/* valley walls rising on both sides */}
      <mesh position={[-12, 6, -20]} castShadow receiveShadow><boxGeometry args={[6, 12, 60]} /><meshStandardMaterial color="#23282a" roughness={0.97} metalness={0} /></mesh>
      <mesh position={[12, 6, -20]} castShadow receiveShadow><boxGeometry args={[6, 12, 60]} /><meshStandardMaterial color="#23282a" roughness={0.97} metalness={0} /></mesh>
      <Collider box={[-12, -20, 6, 60]} />
      <Collider box={[12, -20, 6, 60]} />
      {/* craggy boulders at the cliff feet + a few dead shrubs on the valley floor */}
      <Rock position={[-9, 0, -6]} scale={1.4} seed={31} color="#2c3234" />
      <Rock position={[9, 0, -12]} scale={1.7} seed={32} color="#2c3234" />
      <Rock position={[-9, 0, -24]} scale={1.3} seed={33} color="#30363a" />
      <Rock position={[9, 0, -30]} scale={1.5} seed={34} color="#2c3234" />
      <Tree position={[-7.5, 0, -16]} scale={0.9} dead trunk="#22201c" />
      <Tree position={[7.5, 0, -22]} scale={0.8} dead trunk="#22201c" />
      {/* descending path */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, -16]} receiveShadow><planeGeometry args={[5, 60]} /><meshStandardMaterial color="#3a3d38" roughness={1} metalness={0} /></mesh>

      <ApollyonForeshadow />

      {/* the bow-down spot */}
      <group position={[0, 0, -4]} onClick={(e) => { e.stopPropagation(); if (!humbled) humble() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 0.05, 0]} castShadow receiveShadow><cylinderGeometry args={[1.2, 1.2, 0.1, 20]} /><meshStandardMaterial color={humbled ? '#6a7a5a' : '#4a4a44'} /></mesh>
        <Html center position={[0, 1.2, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">{humbled ? '已俯首谦卑' : '俯首下行（点击）'}</div></Html>
      </group>

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      <hemisphereLight args={['#7a828a', '#15171a', 0.4]} />
      <Player start={[0, 0, 10]} />
    </group>
  )
}

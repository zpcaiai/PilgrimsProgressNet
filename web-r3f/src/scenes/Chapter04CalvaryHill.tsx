import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock, GrassClump, Tree } from '../components/three/NatureKit'
import { GrassField } from '../components/three/InstancedNature'
import { HolyLight } from '../components/three/HolyLight'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

function GreatCross({ lifted, onKneel }: { lifted: boolean; onKneel: () => void }) {
  const glow = lifted ? 2.4 : 0.9
  return (
    <group
      position={[0, 0, -18]}
      onClick={(e) => { e.stopPropagation(); onKneel() }}
      onPointerOver={() => (document.body.style.cursor = 'pointer')}
      onPointerOut={() => (document.body.style.cursor = 'default')}
    >
      <mesh position={[0, 3.4, 0]} castShadow receiveShadow><boxGeometry args={[0.6, 6.8, 0.6]} /><meshStandardMaterial color="#6e5234" emissive="#e8c886" emissiveIntensity={glow * 0.22} roughness={0.8} metalness={0} /></mesh>
      <mesh position={[0, 5.2, 0]} castShadow receiveShadow><boxGeometry args={[3.2, 0.6, 0.6]} /><meshStandardMaterial color="#6e5234" emissive="#e8c886" emissiveIntensity={glow * 0.22} roughness={0.8} metalness={0} /></mesh>
      <pointLight position={[0, 6.5, 1]} intensity={lifted ? 26 : 12} distance={40} color="#ffe8b0" />
      <Html center position={[0, 7.4, 0]} distanceFactor={18}>
        <div className="px-2 py-0.5 text-xs bg-black/65 rounded whitespace-nowrap pointer-events-none">
          {lifted ? '✝ 重担已脱落，滚入空坟' : '✝ 跪在十字架前（点击）'}
        </div>
      </Html>
    </group>
  )
}

function EmptyTomb() {
  return (
    <group position={[9, 0, -20]}>
      <mesh position={[0, 1.4, 0]} castShadow receiveShadow><boxGeometry args={[4, 2.8, 4]} /><meshStandardMaterial color="#5b5550" roughness={0.9} metalness={0} /></mesh>
      <mesh position={[0, 1.1, 2.05]}><boxGeometry args={[1.8, 2, 0.3]} /><meshStandardMaterial color="#0a0a0c" roughness={1} /></mesh>
      <mesh position={[2.6, 0.9, 2]} castShadow receiveShadow><cylinderGeometry args={[0.9, 0.9, 0.5, 24]} /><meshStandardMaterial color="#6b655d" roughness={0.88} metalness={0} /></mesh>
      <Html center position={[0, 3.4, 0]} distanceFactor={18}>
        <div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">空坟 · 死亡已被胜过</div>
      </Html>
    </group>
  )
}

export function Chapter04CalvaryHill() {
  const openChapel = useUiStore((s) => s.openChapel)
  const openRepentance = useUiStore((s) => s.openRepentance)
  const lifted = useGameStore((s) => !!s.gameState.storyFlags.burden_lifted)
  const chapel = getChapelById('chapel_calvary_cross')

  return (
    <group>
      <fog attach="fog" args={['#23211d', 30, 95]} />
      <NaturalGround detail size={[80, 90]} color={lifted ? '#4a4636' : '#332f28'} />
      {/* the small green hill the cross stands on */}
      <mesh position={[0, 0.4, -18]} receiveShadow castShadow><cylinderGeometry args={[7, 8, 0.8, 32]} /><meshStandardMaterial color="#46502f" roughness={0.97} metalness={0} /></mesh>
      {/* grass tufts + a few stones on the knoll, a lone tree off to the side */}
      {[[-3, -17], [2, -19], [-1, -20.5], [3, -16], [0.5, -15], [-4, -19]].map(([x, z], i) => (
        <GrassClump key={i} position={[x, 0.8, z]} color="#5c7a36" />
      ))}
      <Rock position={[5, 0.5, -14]} scale={0.7} seed={6} color="#6b655d" />
      <Rock position={[-5.5, 0.5, -21]} scale={0.9} seed={12} color="#615b52" />
      <Tree position={[13, 0, -10]} scale={1.2} leaf="#3c6638" />
      {/* lush instanced grass on the knoll */}
      <GrassField count={320} area={[13, 12]} center={[0, 0.8, -18]} color="#5c7a36" height={0.5} seed={4} />

      <GreatCross lifted={lifted} onKneel={() => openRepentance('repent_burden_cross')} />
      <EmptyTomb />
      <Collider box={[9, -20, 4, 4]} />{/* the tomb is solid stone */}

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* heavenly light over Calvary */}
      <HolyLight position={[0, 8.5, -18]} color="#ffe9b8" radius={5} intensity={lifted ? 1.6 : 0.85} />
      <pointLight position={[0, 16, -10]} intensity={lifted ? 30 : 16} distance={70} color="#fff0c8" />
      <hemisphereLight args={['#b9c0d6', '#241f1a', lifted ? 0.7 : 0.45]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}

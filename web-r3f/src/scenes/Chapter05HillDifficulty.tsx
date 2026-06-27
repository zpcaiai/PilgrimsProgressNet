import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock, GrassClump, Tree } from '../components/three/NatureKit'
import { GrassField } from '../components/three/InstancedNature'
import { surfaceDetailProps } from '../lib/detailMaps'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'

function Signpost({ x, z, label, color }: { x: number; z: number; label: string; color: string }) {
  return (
    <group position={[x, 0, z]}>
      <mesh position={[0, 1, 0]} castShadow><cylinderGeometry args={[0.08, 0.1, 2, 8]} /><meshStandardMaterial color="#5a4a36" roughness={0.9} metalness={0} /></mesh>
      <mesh position={[0, 1.8, 0]} castShadow><boxGeometry args={[1.6, 0.6, 0.1]} /><meshStandardMaterial color={color} roughness={0.85} metalness={0} /></mesh>
      <Html center position={[0, 1.8, 0.1]} distanceFactor={16}><div className="text-[11px] font-bold pointer-events-none">{label}</div></Html>
    </group>
  )
}

function Arbor() {
  return (
    <group position={[3.5, 0, -14]}>
      {[[-1.2, -1.2], [1.2, -1.2], [-1.2, 1.2], [1.2, 1.2]].map(([x, z], i) => (
        <mesh key={i} position={[x, 1.1, z]} castShadow><cylinderGeometry args={[0.12, 0.12, 2.2, 8]} /><meshStandardMaterial color="#6a5942" roughness={0.9} metalness={0} /></mesh>
      ))}
      <mesh position={[0, 2.3, 0]} castShadow receiveShadow><boxGeometry args={[3, 0.2, 3]} /><meshStandardMaterial color="#7d6a4f" roughness={0.88} metalness={0} /></mesh>
      <mesh position={[0, 0.5, 0]} castShadow><boxGeometry args={[2, 0.3, 1]} /><meshStandardMaterial color="#8a765a" roughness={0.85} metalness={0} /></mesh>
      <Html center position={[0, 3, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">半山凉亭（小心沉睡）</div></Html>
    </group>
  )
}

export function Chapter05HillDifficulty() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const chapel = getChapelById('chapel_hill_difficulty')

  return (
    <group>
      <fog attach="fog" args={['#23241d', 26, 92]} />
      <NaturalGround detail size={[80, 96]} color="#3c4230" />
      {/* instanced scrub grass up the slope */}
      <GrassField count={750} area={[34, 30]} center={[0, 0, -16]} color="#566f33" seed={9} />
      {/* the steep hill (earth + rock) */}
      <mesh position={[0, 4, -26]} castShadow receiveShadow><coneGeometry args={[16, 12, 6]} /><meshStandardMaterial color="#5a5238" roughness={0.97} metalness={0} {...surfaceDetailProps({ normalScale: 0.5 })} /></mesh>
      <Collider circle={[0, -26, 9]} />{/* you cannot walk through the mountain */}
      {/* boulders, scrub and a couple of trees on the slope + flanking the path */}
      <Rock detail position={[-11, 0, -20]} scale={1.3} seed={21} />
      <Rock detail position={[11, 0, -22]} scale={1.1} seed={22} color="#5e5848" />
      <Rock detail position={[-13, 0, -31]} scale={1.6} seed={23} />
      <Rock detail position={[12.5, 0, -33]} scale={1.2} seed={24} color="#5a5446" />
      <Tree detail position={[-13, 0, -14]} scale={1.2} leaf="#46662f" />
      <Tree detail position={[13, 0, -15]} scale={1.1} leaf="#3f5f2c" />
      {[[-6, -12], [6, -13], [-8, -18], [8, -19], [-5, -22], [5, -24]].map(([x, z], i) => (
        <GrassClump key={i} detail position={[x, 0, z]} color="#5a7236" />
      ))}
      {/* straight narrow path up the middle */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.04, -12]} receiveShadow><planeGeometry args={[3, 40]} /><meshStandardMaterial color="#6a5d44" roughness={1} metalness={0} /></mesh>

      <Signpost x={-7} z={-6} label="危险 Danger" color="#7a4a2a" />
      <Signpost x={7} z={-6} label="毁灭 Destruction" color="#6a2a2a" />
      <Arbor />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      <NPCMarker name="Timorous 胆怯(折返)" color="#7a6a5a" position={[-4, 0, 3]} onTalk={() => showToast('胆怯与疑惧劝你回头——山上有狮子。但狮子是被链子锁住的。')} />

      <hemisphereLight args={['#9aa0b8', '#23201a', 0.45]} />
      <Player start={[0, 0, 10]} />
    </group>
  )
}

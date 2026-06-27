import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'

function Picture({ x, z, color }: { x: number; z: number; color: string }) {
  return (
    <group position={[x, 2.6, z]} rotation={[0, x < 0 ? Math.PI / 2 : -Math.PI / 2, 0]}>
      {/* carved wooden frame + painted canvas (no self-glow) */}
      <mesh castShadow><boxGeometry args={[2.3, 1.6, 0.1]} /><meshStandardMaterial color="#4a3a28" roughness={0.8} /></mesh>
      <mesh position={[0, 0, 0.07]}><boxGeometry args={[1.95, 1.25, 0.05]} /><meshStandardMaterial color={color} roughness={0.85} metalness={0} /></mesh>
    </group>
  )
}

function FedFlame() {
  // The fire that burns brighter though one secretly pours oil behind the wall —
  // grace sustaining the soul against the enemy's water.
  return (
    <group position={[0, 0, -11]}>
      <mesh position={[0, 0.4, 0]} castShadow receiveShadow><boxGeometry args={[2.4, 0.8, 1]} /><meshStandardMaterial color="#2f241c" roughness={0.95} metalness={0} /></mesh>
      <mesh position={[0, 1.2, 0]}><coneGeometry args={[0.6, 1.4, 12]} /><meshStandardMaterial color="#ff7a2a" emissive="#ff9a3a" emissiveIntensity={2.2} /></mesh>
      <pointLight position={[0, 1.4, 0.6]} intensity={9} distance={14} color="#ffb060" />
      {/* the hidden one pouring oil from behind the wall */}
      <mesh position={[1.7, 1.0, -0.8]} castShadow><capsuleGeometry args={[0.25, 0.7, 4, 8]} /><meshStandardMaterial color="#caa86a" /></mesh>
      <Html center position={[0, 2.6, 0]} distanceFactor={16}>
        <div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">恩典暗中添油的火</div>
      </Html>
    </group>
  )
}

export function Chapter03InterpreterHouse() {
  const openDialogue = useUiStore((s) => s.openDialogue)
  const openChapel = useUiStore((s) => s.openChapel)
  const chapel = getChapelById('chapel_interpreter_house')

  return (
    <group>
      <fog attach="fog" args={['#1b1712', 26, 70]} />
      {/* floor + walls of the house */}
      <NaturalGround detail size={[20, 28]} color="#5a4632" amp={0} roughness={0.9} />
      <mesh position={[0, 3, -12]} receiveShadow><boxGeometry args={[20, 6, 0.5]} /><meshStandardMaterial color="#6b5740" roughness={0.92} metalness={0} /></mesh>
      <mesh position={[-10, 3, -1]} receiveShadow><boxGeometry args={[0.5, 6, 24]} /><meshStandardMaterial color="#63503b" roughness={0.92} metalness={0} /></mesh>
      <mesh position={[10, 3, -1]} receiveShadow><boxGeometry args={[0.5, 6, 24]} /><meshStandardMaterial color="#63503b" roughness={0.92} metalness={0} /></mesh>
      {/* ceiling beams for an enclosed, lived-in interior */}
      {[-6, 0, 6].map((z) => (
        <mesh key={z} position={[0, 5.7, z]} castShadow><boxGeometry args={[20, 0.4, 0.5]} /><meshStandardMaterial color="#4a3c2c" roughness={0.95} /></mesh>
      ))}
      <Collider box={[0, -12, 20, 0.5]} />
      <Collider box={[-10, -1, 0.5, 24]} />
      <Collider box={[10, -1, 0.5, 24]} />

      <FedFlame />
      <Picture x={-9.6} z={-5} color="#9a8050" />
      <Picture x={9.6} z={-5} color="#7a6a8a" />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      <NPCMarker name="Interpreter 讲解者" color="#4a6a8a" position={[3, 0, -5]} onTalk={() => openDialogue('dialogue_interpreter_welcome')} />

      <hemisphereLight args={['#a08868', '#221a12', 0.5]} />
      <pointLight position={[0, 5, 2]} intensity={8} distance={24} color="#ffdca0" />
      <Player start={[0, 0, 6]} />
    </group>
  )
}

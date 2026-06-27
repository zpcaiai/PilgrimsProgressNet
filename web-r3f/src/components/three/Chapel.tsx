import { Html } from '@react-three/drei'
import type { ChapelData } from '../../types'

const ROOF_COLOR: Record<string, string> = {
  ruined: '#5b5048', gate: '#8a7a5a', calvary: '#caa86a',
  pilgrim: '#7d6a4f', trial: '#6a4f4f', river: '#5f7a86', celestial: '#d9c87a',
}

export function Chapel({ data, onInteract }: { data: ChapelData; onInteract: (c: ChapelData) => void }) {
  const roof = ROOF_COLOR[data.type] ?? '#7d6a4f'
  const crossGlow = data.type === 'celestial' ? 1.3 : 0.35
  return (
    <group
      position={data.position}
      rotation={data.rotation ?? [0, 0, 0]}
      onClick={(e) => { e.stopPropagation(); onInteract(data) }}
      onPointerOver={() => (document.body.style.cursor = 'pointer')}
      onPointerOut={() => (document.body.style.cursor = 'default')}
    >
      <mesh position={[0, 1, 0]} castShadow receiveShadow>
        <boxGeometry args={[2.4, 2, 3]} />
        <meshStandardMaterial color="#cfc6b8" roughness={0.95} metalness={0} />
      </mesh>
      <mesh position={[0, 2.4, 0]} rotation={[0, Math.PI / 4, 0]} castShadow>
        <coneGeometry args={[2.1, 1.2, 4]} />
        <meshStandardMaterial color={roof} roughness={0.85} metalness={0} />
      </mesh>
      {/* cross */}
      <mesh position={[0, 3.6, 0]}>
        <boxGeometry args={[0.12, 1, 0.12]} />
        <meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={crossGlow} />
      </mesh>
      <mesh position={[0, 3.75, 0]}>
        <boxGeometry args={[0.5, 0.12, 0.12]} />
        <meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={crossGlow} />
      </mesh>
      <pointLight position={[0, 2, 1.7]} intensity={5} distance={9} color="#ffd9a0" />
      <Html center position={[0, 4.3, 0]} distanceFactor={16}>
        <div className="px-2 py-0.5 text-xs bg-black/60 rounded whitespace-nowrap pointer-events-none">✝ 小教堂</div>
      </Html>
    </group>
  )
}

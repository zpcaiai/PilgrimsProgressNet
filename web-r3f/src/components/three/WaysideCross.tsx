// A small standing wayside cross — a recurring spiritual marker placed in every
// chapter (and at the pilgrim's home). Purely decorative, with a gentle glow.
export function WaysideCross({
  position = [0, 0, 0],
  scale = 1,
  glow = 0.3,
  woodColor = '#9c7b52',
}: {
  position?: [number, number, number]
  scale?: number
  glow?: number
  woodColor?: string
}) {
  return (
    <group position={position} scale={scale}>
      {/* cairn / stone base */}
      <mesh position={[0, 0.2, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[0.45, 0.6, 0.4, 8]} />
        <meshStandardMaterial color="#6a6157" roughness={0.95} />
      </mesh>
      {/* upright beam */}
      <mesh position={[0, 1.45, 0]} castShadow>
        <boxGeometry args={[0.16, 2.3, 0.16]} />
        <meshStandardMaterial color={woodColor} emissive="#e8d28a" emissiveIntensity={glow} roughness={0.6} />
      </mesh>
      {/* cross beam */}
      <mesh position={[0, 1.75, 0]} castShadow>
        <boxGeometry args={[0.95, 0.16, 0.16]} />
        <meshStandardMaterial color={woodColor} emissive="#e8d28a" emissiveIntensity={glow} roughness={0.6} />
      </mesh>
      <pointLight position={[0, 1.7, 0.5]} intensity={2.2} distance={6} color="#ffdca0" />
    </group>
  )
}

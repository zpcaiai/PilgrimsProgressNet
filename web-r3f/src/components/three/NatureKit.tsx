import { useMemo } from 'react'
import * as THREE from 'three'
import { surfaceDetailProps } from '../../lib/detailMaps'
import { QUALITY } from '../../lib/quality'

type Vec3 = [number, number, number]
const rand = (s: number) => {
  const x = Math.sin(s * 127.1 + 311.7) * 43758.5453
  return x - Math.floor(x)
}

/** An irregular low-poly boulder (jittered icosahedron), matte stone, flat-shaded. */
export function Rock({ position = [0, 0, 0] as Vec3, scale = 1, color = '#6b6157', seed = 1, detail = QUALITY.detail }:
  { position?: Vec3; scale?: number; color?: string; seed?: number; detail?: boolean }) {
  const geo = useMemo(() => {
    const g = new THREE.IcosahedronGeometry(1, 1)
    const p = g.attributes.position as THREE.BufferAttribute
    for (let i = 0; i < p.count; i++) {
      const f = 0.74 + rand(seed * 9 + i) * 0.5
      p.setXYZ(i, p.getX(i) * f, p.getY(i) * f * 0.78, p.getZ(i) * f)
    }
    g.computeVertexNormals()
    return g
  }, [seed])
  return (
    <mesh geometry={geo} position={position} scale={scale} castShadow receiveShadow>
      <meshStandardMaterial color={color} roughness={0.96} metalness={0} flatShading={!detail} {...(detail ? surfaceDetailProps({ normalScale: 0.5 }) : {})} />
    </mesh>
  )
}

/** A small clump of grass blades (a few thin cones). Cheap; place a handful. */
export function GrassClump({ position = [0, 0, 0] as Vec3, color = '#5a7a3a', blades = 5, scale = 1, detail = QUALITY.detail }:
  { position?: Vec3; color?: string; blades?: number; scale?: number; detail?: boolean }) {
  const arr = useMemo(
    () => Array.from({ length: blades }, (_, i) => ({
      a: (i / blades) * Math.PI * 2 + rand(i * 5) * 0.7,
      r: 0.08 + rand(i * 3) * 0.22,
      h: 0.35 + rand(i * 7) * 0.5,
    })),
    [blades],
  )
  return (
    <group position={position} scale={scale}>
      {arr.map((b, i) => (
        <mesh key={i} position={[Math.cos(b.a) * b.r, b.h / 2, Math.sin(b.a) * b.r]} rotation={[rand(i) * 0.3, 0, Math.cos(b.a) * 0.25]} castShadow>
          <coneGeometry args={[0.045, b.h, 4]} />
          <meshStandardMaterial color={color} roughness={1} {...(detail ? surfaceDetailProps({ normal: false }) : {})} />
        </mesh>
      ))}
    </group>
  )
}

/** A low-poly tree (or bare/dead tree), flat-shaded foliage. */
export function Tree({ position = [0, 0, 0] as Vec3, scale = 1, trunk = '#5a4632', leaf = '#3f6a39', dead = false, detail = QUALITY.detail }:
  { position?: Vec3; scale?: number; trunk?: string; leaf?: string; dead?: boolean; detail?: boolean }) {
  return (
    <group position={position} scale={scale}>
      <mesh position={[0, 1, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[0.15, 0.24, 2, 7]} />
        <meshStandardMaterial color={trunk} roughness={1} {...(detail ? surfaceDetailProps({ normalScale: 0.4 }) : {})} />
      </mesh>
      {!dead && (
        <>
          <mesh position={[0, 2.4, 0]} castShadow><icosahedronGeometry args={[1.1, 0]} /><meshStandardMaterial color={leaf} roughness={1} flatShading {...(detail ? surfaceDetailProps({ normal: false }) : {})} /></mesh>
          <mesh position={[0.6, 2.9, 0.3]} castShadow><icosahedronGeometry args={[0.7, 0]} /><meshStandardMaterial color={leaf} roughness={1} flatShading {...(detail ? surfaceDetailProps({ normal: false }) : {})} /></mesh>
          <mesh position={[-0.55, 2.7, -0.3]} castShadow><icosahedronGeometry args={[0.6, 0]} /><meshStandardMaterial color={leaf} roughness={1} flatShading {...(detail ? surfaceDetailProps({ normal: false }) : {})} /></mesh>
        </>
      )}
      {dead && (
        <>
          <mesh position={[0.4, 2.2, 0]} rotation={[0, 0, -0.7]} castShadow><cylinderGeometry args={[0.05, 0.08, 1.1, 5]} /><meshStandardMaterial color={trunk} roughness={1} /></mesh>
          <mesh position={[-0.4, 2.5, 0.2]} rotation={[0, 0, 0.8]} castShadow><cylinderGeometry args={[0.04, 0.07, 0.9, 5]} /><meshStandardMaterial color={trunk} roughness={1} /></mesh>
        </>
      )}
    </group>
  )
}

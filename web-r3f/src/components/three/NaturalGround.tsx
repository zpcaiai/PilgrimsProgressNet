import { useMemo, useEffect } from 'react'
import * as THREE from 'three'
import { makeTriplanarMaterial } from '../../lib/triplanarMaterial'
import { surfaceDetailProps } from '../../lib/detailMaps'
import { QUALITY } from '../../lib/quality'

/**
 * A gently undulating ground patch with a matte, subtly varied surface — reads as
 * real earth / grass / stone instead of a flat painted plane. Drop-in replacement
 * for a flat `<mesh rotation={[-Math.PI/2,0,0]}><planeGeometry/></mesh>` ground.
 * The relief is small (amp) so props stay seated and the (flat-walking) player
 * never clips; it only adds light-catching micro-relief + receives soft shadows.
 */
export function NaturalGround({
  size = [80, 90],
  color = '#4a4636',
  roughness = 1,
  metalness = 0,
  position = [0, 0, 0],
  amp = 0.08,
  seg = 40,
  detail = QUALITY.detail,
  triplanar = QUALITY.triplanarGround,
  detailScale = 0.12,
}: {
  size?: [number, number]
  color?: string
  roughness?: number
  metalness?: number
  position?: [number, number, number]
  amp?: number
  seg?: number
  /** Add procedural micro-surface detail (normal + roughness). */
  detail?: boolean
  /** When `detail`, project the maps triplanar (no UV stretch). Set false for plain UV path. */
  triplanar?: boolean
  /** Triplanar texture frequency (world units). */
  detailScale?: number
}) {
  const geo = useMemo(() => {
    const g = new THREE.PlaneGeometry(size[0], size[1], seg, seg)
    const p = g.attributes.position as THREE.BufferAttribute
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i)
      const y = p.getY(i)
      const h =
        Math.sin(x * 0.15) * Math.cos(y * 0.13) * 0.6 +
        Math.sin(x * 0.37 + 1.3) * Math.cos(y * 0.31 + 0.7) * 0.4
      p.setZ(i, h * amp)
    }
    g.computeVertexNormals()
    return g
  }, [size, seg, amp])

  // Triplanar ground material (only built when detail+triplanar are on).
  const triMat = useMemo(
    () => (detail && triplanar
      ? makeTriplanarMaterial({ color, roughness, metalness, scale: detailScale })
      : null),
    [detail, triplanar, color, roughness, metalness, detailScale],
  )
  useEffect(() => () => { triMat?.dispose() }, [triMat])

  return (
    <mesh
      geometry={geo}
      rotation={[-Math.PI / 2, 0, 0]}
      position={position}
      receiveShadow
      material={triMat ?? undefined}
    >
      {!triMat && (
        <meshStandardMaterial
          color={color}
          roughness={roughness}
          metalness={metalness}
          {...(detail ? surfaceDetailProps() : {})}
        />
      )}
    </mesh>
  )
}

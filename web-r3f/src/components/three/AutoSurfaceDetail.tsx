import { useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { detailNormalMap, detailRoughnessMap } from '../../lib/detailMaps'
import { QUALITY } from '../../lib/quality'

/**
 * Applies the shared procedural detail maps to the **large inline set-pieces** that
 * scenes build by hand (castle walls, buildings, towers, hills, big floors) — the
 * ones NaturalGround / NatureKit don't own. Instead of editing hundreds of inline
 * materials across 16 scenes, it walks the live scene graph for ~1s after each scene
 * change and patches every qualifying MeshStandardMaterial once.
 *
 * Deliberately skips: metals (gates, armour), emissive / glowing meshes, transparent
 * meshes (mist, light shafts, water planes), non-standard materials (e.g. the river's
 * MeshReflectorMaterial), anything already mapped, and small props / characters
 * (size-gated) — so only the matte stone / earth / wood "招牌大件" get detailed.
 *
 * Opt a mesh out explicitly with `material.userData.noDetail = true`.
 */
const MIN_RADIUS = 2.2 // world units — only large set-pieces qualify
const SETTLE_FRAMES = 60 // keep scanning ~1s after a scene change to catch lazy mounts

export function AutoSurfaceDetail({ sceneId }: { sceneId: string }) {
  const scene = useThree((s) => s.scene)
  const done = useRef<WeakSet<THREE.Material>>(new WeakSet())
  const lastScene = useRef<string>('')
  const settle = useRef(0)
  const scratch = useRef(new THREE.Vector3())

  useFrame(() => {
    if (!QUALITY.detail || !QUALITY.autoSetPieces) return
    if (sceneId !== lastScene.current) {
      lastScene.current = sceneId
      settle.current = SETTLE_FRAMES
    }
    if (settle.current <= 0) return
    settle.current--

    const nrm = detailNormalMap()
    const rgh = detailRoughnessMap()
    const tmp = scratch.current

    scene.traverse((obj) => {
      const mesh = obj as THREE.Mesh
      if (!mesh.isMesh || !mesh.geometry) return
      const raw = mesh.material
      if (!raw) return
      const mats = Array.isArray(raw) ? raw : [raw]
      for (const mm of mats) {
        if (done.current.has(mm)) continue
        if (!(mm instanceof THREE.MeshStandardMaterial)) {
          done.current.add(mm)
          continue
        }
        // skip already-mapped, transparent, metal, emissive, opted-out
        const emissive =
          mm.emissive ? (mm.emissive.r + mm.emissive.g + mm.emissive.b) * mm.emissiveIntensity : 0
        if (mm.normalMap || mm.transparent || mm.metalness > 0.5 || emissive > 0.15 || mm.userData.noDetail) {
          done.current.add(mm)
          continue
        }
        // size gate — large set-pieces only (skip small props & characters)
        if (!mesh.geometry.boundingSphere) mesh.geometry.computeBoundingSphere()
        const baseR = mesh.geometry.boundingSphere?.radius ?? 0
        const worldScale = mesh.getWorldScale(tmp).length() / Math.sqrt(3)
        if (baseR * worldScale < MIN_RADIUS) {
          done.current.add(mm)
          continue
        }
        mm.normalMap = nrm
        mm.roughnessMap = rgh
        mm.normalScale = new THREE.Vector2(0.4, 0.4)
        mm.needsUpdate = true
        done.current.add(mm)
      }
    })
  })

  return null
}

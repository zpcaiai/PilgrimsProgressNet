import * as THREE from 'three'
import { detailNormalMap, detailRoughnessMap } from './detailMaps'

export type TriplanarOpts = {
  color: THREE.ColorRepresentation
  roughness?: number
  metalness?: number
  /** texture frequency in world units (larger = finer tiling). */
  scale?: number
  normalScale?: number
}

/**
 * Ground material (P0 #2): a MeshStandardMaterial that projects the shared detail
 * normal + roughness maps **triplanar in object space**, so undulating / tilted
 * ground never shows UV stretch or seams. Built by patching the standard shader
 * via onBeforeCompile (validated against three@0.169 chunk names).
 *
 * If the patched shader ever misbehaves on a given GPU, the material is still a
 * valid standard material — pass `triplanar={false}` to NaturalGround to use the
 * plain UV-mapped detail path instead (same maps, no custom shader).
 */
export function makeTriplanarMaterial(opts: TriplanarOpts): THREE.MeshStandardMaterial {
  const scale = opts.scale ?? 0.12
  const ns = opts.normalScale ?? 0.7
  const mat = new THREE.MeshStandardMaterial({
    color: new THREE.Color(opts.color),
    roughness: opts.roughness ?? 1,
    metalness: opts.metalness ?? 0,
    normalMap: detailNormalMap(),
    roughnessMap: detailRoughnessMap(),
    normalScale: new THREE.Vector2(ns, ns),
  })

  mat.onBeforeCompile = (shader) => {
    shader.uniforms.uTpScale = { value: scale }

    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        '#include <common>\nvarying vec3 vTpPos;\nvarying vec3 vTpNrm;\nvarying mat3 vTpN2V;',
      )
      .replace(
        '#include <beginnormal_vertex>',
        '#include <beginnormal_vertex>\n  vTpNrm = objectNormal;\n  vTpN2V = normalMatrix;',
      )
      .replace(
        '#include <begin_vertex>',
        '#include <begin_vertex>\n  vTpPos = transformed;',
      )

    shader.fragmentShader = shader.fragmentShader
      .replace(
        '#include <common>',
        '#include <common>\nvarying vec3 vTpPos;\nvarying vec3 vTpNrm;\nvarying mat3 vTpN2V;\nuniform float uTpScale;',
      )
      // Triplanar roughness — break up uniform specular by surface noise.
      .replace(
        '#include <roughnessmap_fragment>',
        [
          'float roughnessFactor = roughness;',
          '#ifdef USE_ROUGHNESSMAP',
          '  vec3 tpwR = pow(abs(normalize(vTpNrm)), vec3(4.0));',
          '  tpwR /= (tpwR.x + tpwR.y + tpwR.z);',
          '  float rgh = texture2D(roughnessMap, vTpPos.zy * uTpScale).g * tpwR.x',
          '            + texture2D(roughnessMap, vTpPos.xz * uTpScale).g * tpwR.y',
          '            + texture2D(roughnessMap, vTpPos.xy * uTpScale).g * tpwR.z;',
          '  roughnessFactor *= mix(0.75, 1.1, rgh);',
          '#endif',
        ].join('\n'),
      )
      // Triplanar normal — whiteout blend of three tangent-space samples.
      .replace(
        '#include <normal_fragment_maps>',
        [
          '#ifdef USE_NORMALMAP',
          '  vec3 tpN = normalize(vTpNrm);',
          '  vec3 tpw = pow(abs(tpN), vec3(4.0));',
          '  tpw /= (tpw.x + tpw.y + tpw.z);',
          '  vec3 nX = texture2D(normalMap, vTpPos.zy * uTpScale).xyz * 2.0 - 1.0;',
          '  vec3 nY = texture2D(normalMap, vTpPos.xz * uTpScale).xyz * 2.0 - 1.0;',
          '  vec3 nZ = texture2D(normalMap, vTpPos.xy * uTpScale).xyz * 2.0 - 1.0;',
          '  nX.xy *= normalScale; nY.xy *= normalScale; nZ.xy *= normalScale;',
          '  nX = vec3(nX.xy + tpN.zy, abs(nX.z) * tpN.x);',
          '  nY = vec3(nY.xy + tpN.xz, abs(nY.z) * tpN.y);',
          '  nZ = vec3(nZ.xy + tpN.xy, abs(nZ.z) * tpN.z);',
          '  vec3 nObj = normalize(nX.zyx * tpw.x + nY.xzy * tpw.y + nZ.xyz * tpw.z);',
          '  normal = normalize(vTpN2V * nObj);',
          '#endif',
        ].join('\n'),
      )
  }

  // Keep this patched program distinct in three's program cache.
  mat.customProgramCacheKey = () => 'triplanar-detail-v1'
  return mat
}

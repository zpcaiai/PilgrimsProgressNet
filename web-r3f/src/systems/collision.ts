// Lightweight collision for the R3F world (no physics engine). Scenes and props
// register obstacle volumes here; the Player resolves its desired position against
// them each frame so it can no longer walk through walls, towers, or figures.
//
// Everything is solved in the XZ plane (the world is walked on flat ground). The
// resolution is a circle (the pilgrim) pushed out of boxes / circles, which gives
// natural wall-sliding for free.

export type Obstacle =
  | { kind: 'box'; minX: number; maxX: number; minZ: number; maxZ: number }
  | { kind: 'circle'; x: number; z: number; r: number }

const registry = new Map<string, Obstacle>()

export function setObstacle(id: string, o: Obstacle): void {
  registry.set(id, o)
}

export function removeObstacle(id: string): void {
  registry.delete(id)
}

export function clearObstacles(): void {
  registry.clear()
}

/** Box obstacle from a centre (cx,cz) + size (sx,sz). */
export function boxObstacle(cx: number, cz: number, sx: number, sz: number): Obstacle {
  return { kind: 'box', minX: cx - sx / 2, maxX: cx + sx / 2, minZ: cz - sz / 2, maxZ: cz + sz / 2 }
}

/**
 * Push a desired position (px,pz) out of every obstacle so the pilgrim's circle
 * (radius `pr`) never overlaps one. Two passes settle inside-corners cleanly.
 */
export function resolveCollision(px: number, pz: number, pr: number): [number, number] {
  for (let pass = 0; pass < 2; pass++) {
    for (const o of registry.values()) {
      if (o.kind === 'box') {
        const cx = Math.max(o.minX, Math.min(px, o.maxX))
        const cz = Math.max(o.minZ, Math.min(pz, o.maxZ))
        const dx = px - cx
        const dz = pz - cz
        const d2 = dx * dx + dz * dz
        if (d2 < pr * pr) {
          if (d2 > 1e-8) {
            const d = Math.sqrt(d2)
            const push = pr - d
            px += (dx / d) * push
            pz += (dz / d) * push
          } else {
            // Centre is inside the box: eject along the nearest face.
            const toL = px - o.minX
            const toR = o.maxX - px
            const toB = pz - o.minZ
            const toT = o.maxZ - pz
            const m = Math.min(toL, toR, toB, toT)
            if (m === toL) px = o.minX - pr
            else if (m === toR) px = o.maxX + pr
            else if (m === toB) pz = o.minZ - pr
            else pz = o.maxZ + pr
          }
        }
      } else {
        const dx = px - o.x
        const dz = pz - o.z
        const rr = pr + o.r
        const d2 = dx * dx + dz * dz
        if (d2 < rr * rr) {
          if (d2 > 1e-8) {
            const d = Math.sqrt(d2)
            const push = rr - d
            px += (dx / d) * push
            pz += (dz / d) * push
          } else {
            px += rr
          }
        }
      }
    }
  }
  return [px, pz]
}

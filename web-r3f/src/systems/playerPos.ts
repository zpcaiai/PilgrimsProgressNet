// A tiny shared bus for the pilgrim's current world position, written by the
// Player every frame and read by entities that need to chase / intercept / loom
// (Giant Despair, the river beast) without prop-drilling or re-renders.

export const playerPos = { x: 0, y: 0, z: 0, moving: false }

export function setPlayerPos(x: number, y: number, z: number): void {
  playerPos.x = x
  playerPos.y = y
  playerPos.z = z
}

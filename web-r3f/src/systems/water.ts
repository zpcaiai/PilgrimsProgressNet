// A shared water-zone bus. The River of Death scene publishes the live water band
// (its Z extent + the rising surface height); the Player reads it so that stepping
// into the river sinks the pilgrim to the waist and switches him to a swim stroke.

export type WaterZone = {
  zMin: number
  zMax: number
  surfaceY: number // current world Y of the water surface (rises with fear/doubt)
} | null

let zone: WaterZone = null

export function setWaterZone(z: WaterZone): void {
  zone = z
}

export function getWaterZone(): WaterZone {
  return zone
}

/** True when an XZ position is over the active water band. */
export function inWater(z: number): boolean {
  return zone != null && z <= zone.zMax && z >= zone.zMin
}

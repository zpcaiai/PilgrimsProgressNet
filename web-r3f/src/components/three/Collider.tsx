import { useEffect, useId } from 'react'
import { setObstacle, removeObstacle, boxObstacle, type Obstacle } from '../../systems/collision'

/**
 * Declares a static collision volume for the Player to bump against. Render it
 * anywhere inside a scene next to the wall / prop it guards:
 *   <Collider box={[cx, cz, sx, sz]} />   // centre + size in XZ
 *   <Collider circle={[x, z, r]} />
 * It draws nothing; it registers on mount and clears on unmount.
 */
export function Collider(
  props: { box: [number, number, number, number] } | { circle: [number, number, number] },
) {
  const id = useId()
  const key = JSON.stringify(props)
  useEffect(() => {
    let o: Obstacle
    if ('box' in props) {
      const [cx, cz, sx, sz] = props.box
      o = boxObstacle(cx, cz, sx, sz)
    } else {
      const [x, z, r] = props.circle
      o = { kind: 'circle', x, z, r }
    }
    setObstacle(id, o)
    return () => removeObstacle(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, key])
  return null
}

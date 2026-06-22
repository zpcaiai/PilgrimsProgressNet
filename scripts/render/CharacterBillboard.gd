extends RefCounted
class_name CharacterBillboard
## Shared ground-shadow + soft-disc helpers for the in-engine 3D character
## bodies (HumanoidFigure / HumanoidAnimator) and the player's footstep dust.
## The cast are now real 3D people rather than flat painted billboards, but
## these small primitives remain useful and live here for any caller that needs
## a soft grounded shadow or a round alpha disc.


static var _disc: Texture2D = null

## Soft round white alpha disc (cached). Reused for ground shadows and dust.
static func soft_disc() -> Texture2D:
	if _disc != null:
		return _disc
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n - 1) * 0.5
	for y in range(n):
		for x in range(n):
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var rr := sqrt(dx * dx + dy * dy)
			var a := pow(clampf(1.0 - rr, 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_disc = ImageTexture.create_from_image(img)
	return _disc


## A flat, soft ground-shadow disc to ground a character. Lies on the XZ plane.
static func make_ground_shadow(diameter: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(diameter, diameter)
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.40)
	m.albedo_texture = soft_disc()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

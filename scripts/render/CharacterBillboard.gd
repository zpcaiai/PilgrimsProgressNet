extends RefCounted
class_name CharacterBillboard
## Builds an upright billboard Sprite3D of a character's painted figure, so the
## cast stand in the 3D world as real painted people instead of greybox
## capsules. Y-axis billboard (always faces the camera but stays vertical),
## unshaded so the art reads true under the painterly post-process, with an
## alpha-scissor cutout so transparent figure art (assets/characters/figures/)
## reads cleanly. Feet sit on the ground (y = 0).

static func make(tex: Texture2D, height: float = 2.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.alpha_scissor_threshold = 0.35
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var th := float(tex.get_height())
	if th > 0.0:
		s.pixel_size = height / th
	s.position = Vector3(0, height * 0.5, 0)
	return s

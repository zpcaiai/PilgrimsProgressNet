shader_type canvas_item;
render_mode unshaded;
// ---------------------------------------------------------------------------
// painterly.gdshader — full-screen oil-painting / storybook post-process.
//
// A generalised 4-sector Kuwahara filter flattens fine detail into soft,
// brush-like colour patches (the classic "oil painting" look), then a light
// colour grade, canvas tint, vignette and static paper grain finish it.
//
// Applied by PainterlyPostFX.gd on a full-rect ColorRect in a CanvasLayer that
// sits above the 3D viewport, so it post-processes the whole rendered frame.
// Reads the frame via hint_screen_texture (a back-buffer copy is inserted
// automatically). Works in both Forward+ and gl_compatibility (GLES3/WebGL2):
// loop bounds are constant and no arrays are indexed dynamically.
// ---------------------------------------------------------------------------

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// Overall blend of the painted result over the raw frame (0 = off).
uniform float strength : hint_range(0.0, 1.0) = 0.88;
// Colour grade.
uniform float saturation : hint_range(0.0, 2.0) = 1.10;
uniform float contrast : hint_range(0.5, 1.6) = 1.05;
uniform float brightness : hint_range(0.5, 1.6) = 1.0;
// Warm/cool canvas tint, mixed in lightly.
uniform vec3 tint = vec3(1.0, 0.98, 0.94);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.06;
// Edge darkening.
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.30;
// Static canvas grain.
uniform float grain_amount : hint_range(0.0, 0.3) = 0.03;
// Brush size multiplier (scales the Kuwahara sampling radius in texels).
uniform float brush : hint_range(0.5, 4.0) = 1.0;

// Half-window radius of each Kuwahara sector. 3 -> 4x4 windows, 64 taps total.
const int RADIUS = 3;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Cheap stable hash for static paper grain.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_tex, 0));
	vec2 texel = brush / tex_size;
	vec3 orig = texture(screen_tex, SCREEN_UV).rgb;

	float n = float((RADIUS + 1) * (RADIUS + 1));
	vec3 painted = orig;
	float best = 1.0e9;

	// Four overlapping quadrants around the pixel; keep the one whose luminance
	// varies least, and output its mean colour. That flattens texture inside a
	// region while preserving edges -> brush-stroke patches.
	for (int s = 0; s < 4; s++) {
		float sx = (s == 1 || s == 3) ? 1.0 : -1.0;
		float sy = (s >= 2) ? 1.0 : -1.0;
		vec3 sum = vec3(0.0);
		float sum2 = 0.0;
		for (int i = 0; i <= RADIUS; i++) {
			for (int j = 0; j <= RADIUS; j++) {
				vec2 off = vec2(float(i) * sx, float(j) * sy) * texel;
				vec3 c = texture(screen_tex, SCREEN_UV + off).rgb;
				sum += c;
				float l = luma(c);
				sum2 += l * l;
			}
		}
		vec3 m = sum / n;
		float mean_l = luma(m);
		float variance = abs(sum2 / n - mean_l * mean_l);
		if (variance < best) {
			best = variance;
			painted = m;
		}
	}

	vec3 col = mix(orig, painted, strength);

	// Canvas tint.
	col = mix(col, col * tint, tint_amount);
	// Saturation.
	float l = luma(col);
	col = mix(vec3(l), col, saturation);
	// Contrast + brightness.
	col = (col - 0.5) * contrast + 0.5;
	col *= brightness;
	// Vignette.
	float vig = smoothstep(0.85, 0.32, length(SCREEN_UV - vec2(0.5)));
	col *= mix(1.0, vig, vignette_amount);
	// Static paper grain.
	float g = hash21(SCREEN_UV * tex_size);
	col += (g - 0.5) * grain_amount;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}

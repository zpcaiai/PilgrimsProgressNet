shader_type canvas_item;
render_mode unshaded;

// Cinematic grade for the Devout (realistic) journey.
//
// Until now the realistic mode had NO screen-space grade at all: the painterly
// oil filter was children's-mode only, so every adult chapter rendered raw. That
// left the 16 chapters looking like the same neutral render with different
// props. This shader is the cheap, gl_compatibility-safe half of the fix — the
// Environment supplies tonemap/bloom, this supplies the things Environment has
// no setting for on the compatibility renderer:
//
//   * vignette          (frames the shot, hides the finite ground edge)
//   * film grain        (breaks up flat gradients, kills banding on web)
//   * chromatic edges   (lens character, only in the outer 30% of frame)
//   * per-chapter tint  (the actual per-chapter identity)
//   * lift/gain + sat   (contrast shaping the Environment BCS can't do)
//   * local contrast    (a mild unsharp pass so mid-detail reads at distance)
//
// It runs on ONE full-screen ColorRect below the HUD layer, so UI is untouched.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float vignette_amount : hint_range(0.0, 1.5) = 0.32;
uniform float vignette_softness : hint_range(0.1, 1.5) = 0.62;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.022;
uniform float aberration : hint_range(0.0, 4.0) = 0.7;
uniform float saturation : hint_range(0.0, 2.0) = 1.03;
uniform float contrast : hint_range(0.5, 2.0) = 1.04;
uniform float lift : hint_range(-0.2, 0.2) = 0.008;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.08;
uniform vec3 shadow_tint = vec3(0.92, 0.96, 1.06);
uniform float shadow_tint_amount : hint_range(0.0, 1.0) = 0.18;
uniform float local_contrast : hint_range(0.0, 1.5) = 0.30;
uniform float time_seed = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - vec2(0.5);
	float r2 = dot(centred, centred);

	// --- chromatic aberration, edges only -------------------------------
	vec3 col;
	if (aberration > 0.001) {
		float edge = smoothstep(0.09, 0.32, r2);
		vec2 off = centred * aberration * 0.0022 * edge;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}

	// --- local contrast (unsharp against a blurred mip) -------------------
	if (local_contrast > 0.001) {
		vec3 blurred = textureLod(screen_tex, uv, 3.0).rgb;
		col += (col - blurred) * local_contrast;
	}

	// --- grade: lift, contrast about mid grey, saturation ----------------
	col = max(col + vec3(lift), vec3(0.0));
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	float l = dot(col, LUMA);
	col = mix(vec3(l), col, saturation);

	// --- split tone: cool the shadows, tint the whole frame ---------------
	float shadow_w = 1.0 - smoothstep(0.0, 0.55, l);
	col *= mix(vec3(1.0), shadow_tint, shadow_tint_amount * shadow_w);
	col = mix(col, col * tint, tint_amount);

	// --- vignette ---------------------------------------------------------
	float vig = 1.0 - vignette_amount * smoothstep(vignette_softness * 0.18,
			vignette_softness * 0.72, r2);
	col *= vig;

	// --- grain ------------------------------------------------------------
	if (grain_amount > 0.0001) {
		float g = hash21(uv * vec2(1920.0, 1080.0) + vec2(time_seed, time_seed * 1.7));
		// Grain is strongest in the mids, invisible in the blacks and highlights.
		float mids = 1.0 - abs(l - 0.5) * 1.7;
		col += (g - 0.5) * grain_amount * clamp(mids, 0.0, 1.0);
	}

	vec3 src = texture(screen_tex, uv).rgb;
	COLOR = vec4(mix(src, col, strength), 1.0);
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// ---------------------------------------------------------------------------
// godray.gdshader — an additive volumetric-looking shaft of light.
//
// Meant for a tall vertical cone mesh (wide at top, narrow at bottom). Emits a
// warm beam that is brightest at the top and fades to nothing toward the
// ground, with a gentle living flicker. Pure additive glow, writes no depth, so
// many shafts can overlap into a soft glory without occluding the scene.
// Reads local vertex height (not UV) so it works on any cone orientation.
// ---------------------------------------------------------------------------
uniform vec3 ray_color : source_color = vec3(1.0, 0.94, 0.72);
uniform float intensity = 0.7;
uniform float beam_height = 22.0;
uniform float flicker = 0.15;

varying float v_y;

void vertex() {
	v_y = VERTEX.y;
}

void fragment() {
	// Map local Y (-h/2 .. h/2) to 0 at top, 1 at bottom.
	float t = clamp(0.5 - v_y / beam_height, 0.0, 1.0);
	float fade = 1.0 - t;
	float flick = (1.0 - flicker) + flicker * sin(TIME * 1.2 + v_y * 0.35);
	EMISSION = ray_color * intensity * fade * flick;
	ALPHA = clamp(fade * flick, 0.0, 1.0) * 0.5;
}

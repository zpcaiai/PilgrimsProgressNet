shader_type spatial;
render_mode cull_disabled;
// ---------------------------------------------------------------------------
// water.gdshader — animated painterly water for rivers, swamps and springs.
//
// Gentle vertex swell + a fresnel deep/shallow gradient + a drifting sparkle.
// Writing ALPHA puts it on the transparent pass automatically. Use on a
// subdivided PlaneMesh so the wave displacement reads.
// ---------------------------------------------------------------------------
uniform vec3 shallow : source_color = vec3(0.30, 0.46, 0.52);
uniform vec3 deep : source_color = vec3(0.07, 0.15, 0.22);
uniform float alpha_v : hint_range(0.0, 1.0) = 0.82;
uniform float speed = 0.5;
uniform float wave = 0.06;

void vertex() {
	float w = sin(VERTEX.x * 0.6 + TIME * speed) * wave
			+ cos(VERTEX.z * 0.5 - TIME * speed * 0.8) * wave;
	VERTEX.y += w;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	vec3 col = mix(deep, shallow, f);
	float r = sin(UV.x * 40.0 + TIME * speed * 3.0) * sin(UV.y * 40.0 - TIME * speed * 2.0);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = shallow * max(0.0, r) * 0.06;
	ALPHA = alpha_v;
}

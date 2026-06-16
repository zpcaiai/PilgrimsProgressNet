shader_type spatial;
render_mode cull_back;
// ---------------------------------------------------------------------------
// glory_gold.gdshader — radiant gold for the Celestial City.
//
// Metallic gold that breathes: a slow emissive pulse plus a fresnel rim so
// every tower edge catches light and glows against the sky. Reads as living,
// luminous architecture rather than flat geometry.
// ---------------------------------------------------------------------------
uniform vec3 base_color : source_color = vec3(1.0, 0.82, 0.4);
uniform float metallic_v : hint_range(0.0, 1.0) = 0.7;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.3;
uniform float emit_strength : hint_range(0.0, 3.0) = 0.55;
uniform float rim_strength : hint_range(0.0, 3.0) = 0.9;
uniform float pulse_speed = 0.8;

void fragment() {
	ALBEDO = base_color;
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	EMISSION = base_color * (emit_strength * pulse + fres * rim_strength);
}

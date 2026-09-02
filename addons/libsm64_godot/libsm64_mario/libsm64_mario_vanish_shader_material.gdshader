shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture;
uniform float alpha_threshold = 0.5;
uniform bool alpha_hash = true;
uniform float alpha_hash_scale = 600.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 albedo_tex_rgb = tex.rgb;
	bool has_tex = length(albedo_tex_rgb) > 0.01;
	vec3 final_rgb = has_tex ? albedo_tex_rgb : COLOR.rgb;

	float tex_a = tex.a;
	float vert_a = COLOR.a;
	float final_a = (has_tex ? tex_a : vert_a) * COLOR.b;

	if (alpha_hash) {
		if (final_a < alpha_threshold) {
			float keep_prob = final_a / alpha_threshold;
			float r = rand(SCREEN_UV * alpha_hash_scale);
			if (r > keep_prob) {
				discard;
			}
		}
	} else {
		if (final_a < alpha_threshold) {
			discard;
		}
	}

	ALBEDO = final_rgb;
	ALPHA = final_a;
}

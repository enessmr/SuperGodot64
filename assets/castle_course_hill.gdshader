shader_type spatial;

uniform sampler2D texture_albedo : source_color;

void fragment() {
	float value = texture(texture_albedo, UV).r;

	vec3 color_0 = vec3(0.025, 0.20, 0.007);   // darker #064D02-ish
	vec3 color_1 = vec3(0.09, 0.43, 0.035);    // darker #176E09
	vec3 color_2 = vec3(1.0);                  // #FFFFFF

	if (value < 0.909) {
		ALBEDO = mix(color_0, color_1, value / 0.909);
	} else {
		ALBEDO = mix(color_1, color_2, (value - 0.909) / 0.091);
	}
}

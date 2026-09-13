shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear, repeat_enable;

uniform bool scroll_x = true;
uniform bool scroll_y = false;

uniform float scroll_speed_x = 1.0;
uniform float scroll_speed_y = 0.0;

uniform float alpha = 0.7;

void fragment() {
vec2 scroll = vec2(
scroll_x ? scroll_speed_x : 0.0,
scroll_y ? scroll_speed_y : 0.0
);

vec2 scrolled_uv = UV + scroll * TIME;
vec4 albedo = texture(albedo_texture, scrolled_uv);

ALBEDO = albedo.rgb;
ALPHA = albedo.a * alpha;

}

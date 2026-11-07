shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float emission_strength = 1.5;
uniform float limb_darkening = 0.55;
uniform float scroll_speed = 0.004;

void fragment() {
	vec2 uv = UV + vec2(TIME * scroll_speed, 0.0);
	vec3 color = texture(albedo_texture, uv).rgb;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = mix(1.0 - limb_darkening, 1.0, pow(facing, 0.5));
	ALBEDO = color * emission_strength * limb;
}

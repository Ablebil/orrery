shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.9;
uniform bool has_sun = true;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float ambient = 0.03;
uniform float terminator_softness = 0.12;
uniform float night_opacity = 0.35;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float cover = texture(cloud_texture, UV).r;
	float n_dot_l = dot(normalize(world_normal), normalize(sun_direction));
	float day = has_sun ? smoothstep(-terminator_softness, terminator_softness, n_dot_l) : 0.0;
	float lambert = clamp(n_dot_l, 0.0, 1.0);
	ALBEDO = vec3(mix(ambient, 0.3 + 0.7 * lambert, day));
	ALPHA = cover * opacity * mix(night_opacity, 1.0, day);
}

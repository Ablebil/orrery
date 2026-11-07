shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_night_texture = false;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float ambient = 0.04;
uniform float terminator_softness = 0.1;
uniform float night_strength = 1.3;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb;
	float n_dot_l = dot(normalize(world_normal), normalize(sun_direction));
	float day = smoothstep(-terminator_softness, terminator_softness, n_dot_l);
	float lambert = clamp(n_dot_l, 0.0, 1.0);
	vec3 day_color = albedo * (0.25 + 0.75 * lambert);
	vec3 night_color = albedo * ambient;
	if (has_night_texture) {
		night_color += texture(night_texture, UV).rgb * night_strength;
	}
	ALBEDO = mix(night_color, day_color, day);
}

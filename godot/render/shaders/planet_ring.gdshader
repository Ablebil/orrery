shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D ring_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform bool has_sun = true;
uniform float ambient = 0.06;
uniform float back_light = 0.65;

void fragment() {
	vec4 ring = texture(ring_texture, vec2(UV.x, 0.5));
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 planet_center = MODEL_MATRIX[3].xyz;
	float planet_radius = length(MODEL_MATRIX[0].xyz);
	vec3 ring_normal = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 light = normalize(sun_direction);
	float lit = has_sun ? 1.0 : 0.0;
	vec3 to_center = planet_center - world_position;
	float along = dot(to_center, light);
	if (along > 0.0 && dot(to_center, to_center) - along * along < planet_radius * planet_radius) {
		lit = 0.0;
	}
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
	bool same_side = dot(ring_normal, light) * dot(ring_normal, view_direction) >= 0.0;
	float facing = abs(dot(ring_normal, light));
	float direct = (0.55 + 0.45 * facing) * (same_side ? 1.0 : back_light);
	ALBEDO = ring.rgb * mix(ambient, direct, lit);
	ALPHA = ring.a;
}

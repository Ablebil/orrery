shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 atmosphere_color : source_color = vec4(0.36, 0.62, 1.0, 1.0);
uniform float thickness = 0.025;
uniform float intensity = 1.0;
uniform bool has_sun = true;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform bool full_detail = true;
uniform float density_falloff = 1.6;
uniform float twilight = 0.2;
uniform float scatter_power = 8.0;
uniform float scatter_strength = 1.5;
uniform float terminator_width = 0.45;

void fragment() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float shell_radius = length(MODEL_MATRIX[0].xyz);
	float planet_radius = shell_radius / (1.0 + thickness);
	float shell_sq = shell_radius * shell_radius;
	float planet_sq = planet_radius * planet_radius;
	bool inside = dot(center, center) < shell_sq;
	if (!inside && !FRONT_FACING) {
		discard;
	}
	vec3 ray = normalize(VERTEX);
	float along = dot(center, ray);
	vec3 closest = center - ray * along;
	float closest_sq = dot(closest, closest);
	float shell_half = sqrt(max(shell_sq - closest_sq, 0.0));
	float planet_half = sqrt(max(planet_sq - closest_sq, 0.0));
	bool hits_planet = along > 0.0 && closest_sq < planet_sq;
	float path;
	vec3 sample_normal;
	if (inside) {
		path = hits_planet ? along - planet_half : along + shell_half;
		sample_normal = normalize(-center);
	} else {
		path = hits_planet ? shell_half - planet_half : 2.0 * shell_half;
		sample_normal = hits_planet ? normalize(-closest - ray * planet_half) : normalize(-closest);
	}
	float density = clamp(path / (2.0 * sqrt(shell_sq - planet_sq)), 0.0, 1.0);
	float glow = pow(density, density_falloff);
	float strength = 0.0;
	if (has_sun) {
		vec3 light = normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz);
		float n_dot_l = dot(sample_normal, light);
		strength = glow * smoothstep(-twilight, twilight, n_dot_l);
		if (full_detail) {
			float forward = pow(max(dot(ray, light), 0.0), scatter_power);
			float terminator = 1.0 - smoothstep(0.0, terminator_width, abs(n_dot_l));
			strength += glow * forward * terminator * scatter_strength;
		}
	}
	ALBEDO = atmosphere_color.rgb;
	ALPHA = clamp(strength * intensity, 0.0, 1.0);
}

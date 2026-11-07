shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 halo_color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float intensity = 1.0;
uniform float falloff_power = 2.4;

void vertex() {
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 scaling = mat4(
		vec4(scale.x, 0.0, 0.0, 0.0),
		vec4(0.0, scale.y, 0.0, 0.0),
		vec4(0.0, 0.0, scale.z, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * scaling;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = clamp(1.0 - length(centered), 0.0, 1.0);
	ALBEDO = halo_color.rgb;
	ALPHA = clamp(pow(radial, falloff_power) * intensity, 0.0, 1.0);
}

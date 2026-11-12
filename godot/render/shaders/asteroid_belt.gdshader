shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled;

uniform float phase_coarse = 0.0;
uniform float phase_fine = 0.0;
uniform vec3 sun_offset = vec3(0.0);
uniform float shell = 1.0e9;
uniform bool compressed = true;
uniform float orbit_base = 10.0;
uniform float orbit_factor = 18.0;
uniform float orbit_exponent = 0.55;
uniform float au_units = 149597.8707;
uniform float unit_km = 1000.0;
uniform float earth_radius_km = 6371.0;
uniform float radius_exponent = 0.5;
uniform float min_angular_radius = 0.0011;
uniform vec4 rock_color : source_color = vec4(0.58, 0.53, 0.47, 1.0);
uniform float ambient = 0.06;

varying vec3 shade;

void vertex() {
	vec3 axis_p = MODEL_MATRIX[0].xyz;
	vec3 axis_q = MODEL_MATRIX[1].xyz;
	vec3 axis_w = MODEL_MATRIX[2].xyz;
	float multiple = MODEL_MATRIX[3].x;
	float revolutions = fract(multiple * phase_coarse) + multiple * phase_fine + MODEL_MATRIX[3].y;
	float semi_major = MODEL_MATRIX[3].z;
	float eccentricity = INSTANCE_CUSTOM.x;
	float rock_radius_km = INSTANCE_CUSTOM.y;
	float mean_anomaly = (fract(revolutions + 0.5) - 0.5) * TAU;
	float eccentric_anomaly = mean_anomaly + eccentricity * sin(mean_anomaly);
	for (int iteration = 0; iteration < 4; iteration++) {
		eccentric_anomaly -= (eccentric_anomaly - eccentricity * sin(eccentric_anomaly) - mean_anomaly)
				/ (1.0 - eccentricity * cos(eccentric_anomaly));
	}
	vec3 orbit_au = axis_p * (semi_major * (cos(eccentric_anomaly) - eccentricity))
			+ axis_q * (semi_major * sqrt(1.0 - eccentricity * eccentricity) * sin(eccentric_anomaly));
	float radius_au = max(length(orbit_au), 1.0e-6);
	vec3 heliocentric;
	float body_radius;
	if (compressed) {
		heliocentric = orbit_au / radius_au * (orbit_base + orbit_factor * pow(radius_au, orbit_exponent));
		body_radius = pow(rock_radius_km / earth_radius_km, radius_exponent);
	} else {
		heliocentric = orbit_au * au_units;
		body_radius = rock_radius_km / unit_km;
	}
	vec3 center = sun_offset + heliocentric;
	float camera_distance = max(length(center), 1.0e-9);
	float shrink = min(1.0, shell / camera_distance);
	float display_radius = max(body_radius, camera_distance * min_angular_radius) * shrink;
	mat3 rock_basis = mat3(axis_p, axis_q, axis_w);
	vec3 world_position = center * shrink + rock_basis * VERTEX * display_radius;
	vec3 world_normal = normalize(rock_basis * NORMAL);
	VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float lambert = max(dot(world_normal, normalize(-heliocentric)), 0.0);
	shade = rock_color.rgb * (ambient + (1.0 - ambient) * lambert);
}

void fragment() {
	ALBEDO = shade;
}

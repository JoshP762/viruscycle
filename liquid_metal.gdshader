shader_type spatial;

// --- Appearance ---
uniform vec3 base_color : source_color = vec3(0.7, 0.75, 0.8);
uniform vec3 ripple_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.95;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.05;

// --- Ripple shape ---
uniform float ripple_frequency : hint_range(1.0, 20.0) = 6.0;   // Rings per unit
uniform float ripple_speed : hint_range(0.0, 10.0) = 3.5;        // How fast rings expand
uniform float ripple_radius : hint_range(1.0, 30.0) = 12.0;      // Max reach of ripple
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.6;      // Brightness of rings
uniform float ripple_height : hint_range(0.0, 0.5) = 0.08;       // Vertex displacement

// --- Wheel positions (set from GDScript each frame) ---
uniform vec3 wheel_left  = vec3(0.0, 0.0, 0.0);
uniform vec3 wheel_right = vec3(0.0, 0.0, 0.0);

// --- Bike speed (drives wake intensity) ---
uniform float bike_speed : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

float ripple_wave(vec3 surface, vec3 source, float time_offset) {
	float dist = length(surface.xz - source.xz);
	float falloff = 1.0 - smoothstep(0.0, ripple_radius, dist);
	float wave = sin(dist * ripple_frequency - TIME * ripple_speed + time_offset);
	return wave * falloff * bike_speed;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float r1 = ripple_wave(world_pos, wheel_left,  0.0);
	float r2 = ripple_wave(world_pos, wheel_right, 1.2);
	float combined = (r1 + r2) * 0.5;

	// Displace vertices up/down to create actual surface ripple
	VERTEX.y += combined * ripple_height * ripple_strength;

	// Recalculate normal from displacement for correct lighting
	float eps = 0.1;
	vec3 neighbour_x = world_pos + vec3(eps, 0.0, 0.0);
	vec3 neighbour_z = world_pos + vec3(0.0, 0.0, eps);

	float r1x = ripple_wave(neighbour_x, wheel_left, 0.0);
	float r2x = ripple_wave(neighbour_x, wheel_right, 1.2);
	float r1z = ripple_wave(neighbour_z, wheel_left, 0.0);
	float r2z = ripple_wave(neighbour_z, wheel_right, 1.2);

	float dx = ((r1x + r2x) * 0.5 - combined) * ripple_height * ripple_strength / eps;
	float dz = ((r1z + r2z) * 0.5 - combined) * ripple_height * ripple_strength / eps;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float r1 = ripple_wave(world_pos, wheel_left,  0.0);
	float r2 = ripple_wave(world_pos, wheel_right, 1.2);
	float combined = clamp((r1 + r2) * 0.5 * ripple_strength, -1.0, 1.0);

	// Blend base color with bright ripple crests
	float crest = smoothstep(0.3, 1.0, combined);
	vec3 color = mix(base_color, ripple_color, crest);

	// Subtle base shimmer even without movement
	float shimmer = sin(world_pos.x * 3.0 + world_pos.z * 2.0 + TIME * 0.4) * 0.03;
	color += shimmer;

	ALBEDO = color;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount - crest * 0.04;
	SPECULAR = 1.0;
}

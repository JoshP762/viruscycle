shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Color ---
uniform vec3 base_color : source_color = vec3(0.75, 0.78, 0.82);
uniform vec3 sheen_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_amount : hint_range(0.0, 0.3) = 0.08;

// --- Flow (two normal layers scrolling at different speeds/angles) ---
uniform sampler2D normal_map_a : hint_normal;
uniform sampler2D normal_map_b : hint_normal;
uniform float flow_speed_a : hint_range(0.0, 1.0) = 0.04;
uniform float flow_speed_b : hint_range(0.0, 1.0) = 0.02;
uniform float normal_scale : hint_range(0.0, 2.0) = 0.35;
uniform float tiling : hint_range(0.1, 10.0) = 2.5;

// --- Fresnel ---
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.4;

// --- Wheel ripples ---
uniform vec3 wheel_left  = vec3(0.0);
uniform vec3 wheel_right = vec3(0.0);
uniform float bike_speed : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_frequency : hint_range(1.0, 15.0) = 5.0;
uniform float ripple_speed : hint_range(0.0, 8.0) = 3.0;
uniform float ripple_radius : hint_range(1.0, 20.0) = 8.0;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 world_pos;

float ripple(vec3 surface, vec3 source) {
	float dist = length(surface.xz - source.xz);
	float falloff = 1.0 - smoothstep(0.0, ripple_radius, dist);
	return sin(dist * ripple_frequency - TIME * ripple_speed) * falloff * bike_speed;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * (1.0 / tiling);

	// Two normal maps scrolling in slightly different directions
	vec2 flow_a = vec2(TIME * flow_speed_a, TIME * flow_speed_a * 0.6);
	vec2 flow_b = vec2(-TIME * flow_speed_b * 0.7, TIME * flow_speed_b);

	vec3 n_a = texture(normal_map_a, uv + flow_a).rgb;
	vec3 n_b = texture(normal_map_b, uv * 1.4 + flow_b).rgb;
	vec3 blended_normal = normalize(mix(n_a, n_b, 0.5) * 2.0 - 1.0);
	blended_normal.xy *= normal_scale;

	// Ripple contribution to normal
	float r_left  = ripple(world_pos, wheel_left);
	float r_right = ripple(world_pos, wheel_right);
	float r_total = (r_left + r_right) * ripple_strength;
	blended_normal.xy += vec2(r_total * 0.3);

	NORMAL_MAP = normalize(blended_normal) * 0.5 + 0.5;

	// Fresnel sheen on edges
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	vec3 color = mix(base_color, sheen_color, fresnel * fresnel_strength);

	// Subtle ripple brightening on crests
	color += vec3(clamp(r_total, 0.0, 1.0) * 0.15);

	ALBEDO    = color;
	METALLIC  = metallic_amount;
	ROUGHNESS = roughness_amount;
	SPECULAR  = 1.0;
	NORMAL_MAP_DEPTH = normal_scale;
}

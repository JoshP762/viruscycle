shader_type spatial;
render_mode depth_draw_always;

const float EPSILON = 1e-5;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE  : hint_depth_texture,  filter_nearest;

uniform vec3 color_shallow : source_color = vec3(0.75, 0.78, 0.82);
uniform vec3 color_deep    : source_color = vec3(0.45, 0.48, 0.52);
uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float metallic     : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float roughness    : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float max_visible_depth : hint_range(0.1, 100.0, 0.1) = 30.0;

uniform sampler2D wave_a;
uniform sampler2D wave_b;
uniform vec2  wave_move_direction_a = vec2(-1.0, 0.0);
uniform vec2  wave_move_direction_b = vec2(0.0,  1.0);
uniform float wave_noise_scale_a    = 20.0;
uniform float wave_noise_scale_b    = 20.0;
uniform float wave_time_scale_a     = 0.05;
uniform float wave_time_scale_b     = 0.05;
uniform float wave_height_scale     = 0.15;
uniform float wave_normal_flatness : hint_range(0.1, 100.0, 0.1) = 80.0;

uniform sampler2D surface_normals_a;
uniform sampler2D surface_normals_b;
uniform vec2  surface_normals_move_direction_a = vec2(-1.0, 0.2);
uniform vec2  surface_normals_move_direction_b = vec2(0.2,  1.0);
uniform float surface_texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float surface_texture_scale     : hint_range(0.001, 2.0, 0.001) = 0.08;
uniform float surface_texture_time_scale: hint_range(0.001, 2.0, 0.001) = 0.03;

uniform float ssr_resolution            : hint_range(0.01, 10.0, 0.1) = 2.0;
uniform float ssr_max_travel            : hint_range(0.0, 200.0, 0.1) = 40.0;
uniform float ssr_max_diff              : hint_range(0.1, 10.0, 0.1)  = 4.0;
uniform float ssr_mix_strength          : hint_range(0.0, 1.0, 0.01)  = 0.85;
uniform float ssr_screen_border_fadeout : hint_range(0.0, 1.0, 0.1)   = 0.3;

uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.1;

uniform vec3  wheel_left    = vec3(0.0);
uniform vec3  wheel_right   = vec3(0.0);
uniform vec3  bike_forward  = vec3(0.0, 0.0, 1.0);
uniform float bike_speed    : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_frequency  : hint_range(1.0, 15.0) = 5.0;
uniform float ripple_speed      : hint_range(0.0, 8.0)  = 3.0;
uniform float ripple_radius     : hint_range(1.0, 20.0) = 10.0;
uniform float ripple_strength   : hint_range(0.0, 1.0)  = 0.3;
uniform float wake_stretch      : hint_range(1.0, 6.0)  = 3.0;

varying vec2 vertex_uv;
varying vec3 local_position;
varying vec3 world_pos;

float get_wave_height(vec2 uv_a, vec2 uv_b) {
	return (texture(wave_a, uv_a).y + texture(wave_b, uv_b).y) / 2.0;
}

vec3 get_mixed_normals(vec3 c1, vec3 c2) {
	vec3 n1 = normalize(c1 * 2.0 - 1.0);
	vec3 n2 = normalize(c2 * 2.0 - 1.0);
	vec3 up = vec3(0.0, 0.0, 1.0);
	vec3 tangent  = normalize(n1 + n2);
	vec3 binormal = normalize(cross(up, tangent));
	return normalize(cross(tangent, binormal)) * 0.5;
}

bool is_within_screen_boundaries(vec2 p) {
	return p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 pos_view, mat4 proj_m) {
	vec4 clip = proj_m * vec4(pos_view, 1.0);
	return (clip.xy / clip.w) * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m) {
	vec4 ndc  = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view = inv_proj_m * ndc;
	return view.xyz / view.w;
}

bool is_zero(float v) { return abs(v) < EPSILON; }

float get_screen_border_alpha(vec2 sp) {
	vec2 shifted = 4.0 * sp * (1.0 - sp);
	float mask   = shifted.x * shifted.y;
	float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0) - 0.75) / 0.25);
	return is_zero(ssr_screen_border_fadeout) ? 1.0 : clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);
}

vec4 get_ssr_color(vec3 surf_view, vec3 norm_view, vec3 view_vs, mat4 proj_m, mat4 inv_proj_m) {
	if (ssr_max_travel < EPSILON) return vec4(0);
	vec3 cur  = surf_view;
	vec3 refl = normalize(reflect(view_vs * -1.0, norm_view));
	vec2 cur_sp = vec2(0.0);
	vec3 result = vec3(-1.0);
	for (float t = 0.0; result.x < 0.0 && t < ssr_max_travel; t += ssr_resolution) {
		cur += refl * ssr_resolution;
		cur_sp = get_uv_from_view_position(cur, proj_m);
		float depth_raw  = texture(DEPTH_TEXTURE, cur_sp).x;
		vec3  depth_view = get_view_position_from_uv(cur_sp, depth_raw, inv_proj_m);
		float diff = depth_view.z - cur.z;
		vec3  col  = texture(SCREEN_TEXTURE, cur_sp.xy).rgb;
		result = (is_within_screen_boundaries(cur_sp) && diff >= 0.0 && diff < ssr_max_diff) ? col : vec3(-1.0);
	}
	return vec4(result, get_screen_border_alpha(cur_sp));
}

vec2 get_refracted_uv(vec2 raw_uv, float depth_raw, vec3 view, vec3 normal, mat4 proj_m, mat4 inv_proj_m) {
	vec3  orig = get_view_position_from_uv(raw_uv, depth_raw, inv_proj_m);
	float dist = clamp(abs(length(raw_uv - vec2(0.5))) * 2.0, 0.0, 1.0);
	float ri   = mix(1.0 - refraction_intensity, 1.0, dist);
	return get_uv_from_view_position(orig + normalize(refract(view, -normal, ri)), proj_m);
}

float normalize_float(float mn, float mx, float v) {
	return (clamp(v, mn, mx) - mn) / (mx - mn);
}

float ripple(vec3 surface, vec3 source, vec3 forward) {
	vec3 to    = surface - source; to.y = 0.0;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	float along  = dot(to, forward);
	float across = dot(to, right);
	float dist   = sqrt((along / wake_stretch) * (along / wake_stretch) + across * across);
	float behind = smoothstep(0.5, -2.0, along);
	float fade   = (1.0 - smoothstep(0.0, ripple_radius, dist)) * behind;
	return sin(dist * ripple_frequency - TIME * ripple_speed) * fade * bike_speed;
}

void vertex() {
	local_position = VERTEX;
	world_pos      = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_uv      = world_pos.xz;

	vec2 uv_a = vertex_uv / wave_noise_scale_a + wave_move_direction_a * TIME * wave_time_scale_a;
	vec2 uv_b = vertex_uv / wave_noise_scale_b + wave_move_direction_b * TIME * wave_time_scale_b;
	VERTEX.y += get_wave_height(uv_a, uv_b) * wave_height_scale;

	float nhs = wave_height_scale / wave_normal_flatness;
	vec2 e    = vec2(0.01, 0.0);
	NORMAL    = normalize(vec3(
		get_wave_height(uv_a - e,    uv_b - e)    * nhs - get_wave_height(uv_a + e,    uv_a + e)    * nhs,
		2.0 * e.x,
		get_wave_height(uv_a - e.yx, uv_b - e.yx) * nhs - get_wave_height(uv_a + e.yx, uv_b + e.yx) * nhs
	));
}

void fragment() {
	vec3  normal           = NORMAL;
	float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;

	vec2 refraction_uv = refraction_intensity > 0.0
		? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, normal, PROJECTION_MATRIX, INV_PROJECTION_MATRIX)
		: SCREEN_UV;

	float screen_depth  = texture(DEPTH_TEXTURE, refraction_uv).x;
	float surface_depth = FRAGCOORD.z;

	vec2 tv1 = TIME * surface_normals_move_direction_a * surface_texture_time_scale;
	vec2 tv2 = TIME * surface_normals_move_direction_b * surface_texture_time_scale;
	vec3 nt  = get_mixed_normals(
		texture(surface_normals_a, vertex_uv * surface_texture_scale + tv1).xyz,
		texture(surface_normals_b, vertex_uv * surface_texture_scale + tv2).xyz
	);
	vec3 normal_blend = mix(normal, nt, surface_texture_roughness);

	vec3  fwd = normalize(bike_forward + vec3(0.0001));
	float r   = (ripple(world_pos, wheel_left, fwd) + ripple(world_pos, wheel_right, fwd)) * ripple_strength;
	normal_blend.xy += vec2(r * 0.25);

	vec3  screen_view  = get_view_position_from_uv(refraction_uv, screen_depth, INV_PROJECTION_MATRIX);
	vec3  surface_view = get_view_position_from_uv(SCREEN_UV, surface_depth, INV_PROJECTION_MATRIX);
	float depth_vis    = 1.0 - normalize_float(0.0, max_visible_depth, length(surface_view - screen_view));

	vec3 screen_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;
	vec4 ssr          = get_ssr_color(surface_view, normal, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	vec3 surf_transp  = mix(color_shallow, screen_color, transparency);
	vec3 depth_mix    = mix(color_deep, surf_transp, depth_vis);
	vec3 ssr_mix      = (ssr_max_travel > EPSILON) ? mix(depth_mix, ssr.rgb, ssr_mix_strength * ssr.a) : vec3(0);
	vec3 final        = (ssr.x >= 0.0) ? ssr_mix : depth_mix;
	final += vec3(clamp(r, 0.0, 1.0) * 0.12);

	ALBEDO    = final;
	METALLIC  = metallic;
	ROUGHNESS = roughness;
	NORMAL    = normal_blend;
}
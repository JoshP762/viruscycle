shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float angle = atan(uv.y, -uv.x);
	float normalized_angle = (angle + PI) / (2.0 * PI);

	if (normalized_angle <= fill_amount) {
		COLOR = fill_color;
	} else {
		COLOR = vec4(0.0);
	}
}
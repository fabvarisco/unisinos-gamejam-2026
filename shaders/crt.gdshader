shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : source_color, filter_linear;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = dot(centered, centered);
	vec2 uv = UV + centered * dist * 0.06;
	vec3 color = vec3(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		float shift = 0.0016 * dist;
		float red = texture(screen_tex, uv + vec2(shift, 0.0)).r;
		float green = texture(screen_tex, uv).g;
		float blue = texture(screen_tex, uv - vec2(shift, 0.0)).b;
		color = vec3(red, green, blue);
		float scan = 0.78 + 0.22 * sin(uv.y * 240.0 * PI);
		color *= scan;
		float grille = 0.9 + 0.1 * sin(uv.x * 640.0 * PI);
		color *= grille;
		float edge = smoothstep(0.25, 1.2, length(centered));
		color *= mix(1.0, 0.55, edge);
	}
	ALBEDO = color;
}

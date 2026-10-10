shader_type canvas_item;

uniform sampler2D from_tex;
uniform sampler2D to_tex;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float min_tiles = 1.0;
uniform float max_tiles = 200.0;

void fragment() {
	vec2 screen_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 fragCoord = UV * screen_size;
	vec2 sample_uv = UV;

	if (progress > 0.0 && progress < 1.0) {
		float transition_curve = abs(progress - 0.5) * 2.0;
		float count = mix(min_tiles, max_tiles, transition_curve);
		count = floor(count);
		vec2 tileSize = screen_size / count;
		vec2 sample_pos = floor(fragCoord / tileSize) * tileSize + tileSize * 0.5;
		sample_uv = sample_pos / screen_size;
	}

	vec4 from_col = texture(from_tex, sample_uv);
	vec4 to_col = texture(to_tex, sample_uv);
	COLOR = mix(from_col, to_col, progress);
}

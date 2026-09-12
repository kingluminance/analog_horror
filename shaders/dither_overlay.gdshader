shader_type canvas_item;

// Full-screen retro pass: color-depth dithering, scanlines, grain, chromatic aberration, vignette.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float dither_scale : hint_range(1.0, 8.0) = 2.0;
uniform float color_levels : hint_range(2.0, 16.0) = 4.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float aberration_strength : hint_range(0.0, 0.01) = 0.003;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
) / 16.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 center_dir = SCREEN_UV - vec2(0.5);
	vec2 offset = center_dir * aberration_strength;
	vec3 color;
	color.r = texture(screen_tex, SCREEN_UV + offset).r;
	color.g = texture(screen_tex, SCREEN_UV).g;
	color.b = texture(screen_tex, SCREEN_UV - offset).b;
	float alpha = texture(screen_tex, SCREEN_UV).a;

	ivec2 pixel = ivec2(FRAGCOORD.xy / dither_scale) % 4;
	float threshold = (BAYER[pixel.x][pixel.y] - 0.5) / color_levels;
	vec3 dithered = floor((color + threshold) * color_levels) / color_levels;

	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 1.5));
	float grain = (hash(FRAGCOORD.xy + fract(TIME) * 1000.0) - 0.5) * grain_strength;
	float vignette = 1.0 - vignette_strength * length(center_dir);

	vec3 final_color = (dithered + grain) * scanline * vignette;
	COLOR = vec4(final_color, alpha);
}

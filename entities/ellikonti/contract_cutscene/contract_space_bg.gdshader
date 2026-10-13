shader_type canvas_item;
// Background of the scene you land in after Ellikonti swallows you (user's
// storyboard "배경"): flat blue, pink torn-looking chunks and green dots
// drifting steadily to the left forever. Drawn at a low virtual resolution
// so it pixelates like everything else (the PostProcess dither goes on top).

uniform vec4 bg_color : source_color = vec4(0.33, 0.40, 0.98, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.16, 0.83, 1.0);
uniform vec4 green : source_color = vec4(0.30, 0.80, 0.36, 1.0);
uniform float speed = 0.35; // cells per second, leftward
uniform float cells_tall = 5.0;
uniform vec2 pixel_res = vec2(320.0, 180.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = (floor(UV * pixel_res) + 0.5) / pixel_res;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // width / height
	vec2 p = vec2(uv.x * aspect, uv.y) * cells_tall;
	p.x += TIME * speed; // sampling further right over time = shapes move left
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	vec2 c = (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.35;
	float kind = hash(cell);
	vec3 col = bg_color.rgb;
	if (kind < 0.45) {
		float r = 0.13 + 0.06 * hash(cell + 1.3);
		if (length(f - c) < r) col = green.rgb;
	} else if (kind < 0.85) {
		// pink chunk: rotated ellipse with a bite taken out of it
		float a = hash(cell + 5.5) * 6.2831;
		mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		vec2 q = rot * (f - c);
		float body = length(q / vec2(0.30, 0.19));
		float bite = length((q - vec2(0.16, 0.15)) / vec2(0.14, 0.10));
		if (body < 1.0 && bite > 1.0) col = pink.rgb;
	}
	COLOR = vec4(col, 1.0);
}

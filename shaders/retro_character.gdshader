shader_type spatial;
// PS1-era character look for low-poly 3D characters (first user: Ellikonti).
//  - curved_world.gdshader's world bend, so characters sit on the same curve
//  - vertex snapping to a coarse screen grid: polygons jitter/creep a pixel at
//    a time as the camera moves, the classic PS1 wobble
//  - tiny nearest-filtered painted texture, cheap fixed "light from above"
//    shading (unshaded, so the bright daylight scene can't wash it out)
//  - colour posterised with a 4x4 ordered dither
//  - optional face layers (eyes / mouth / extra) projected along the mesh's
//    local +Z, so expressions are swappable textures instead of geometry
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float curve_strength : hint_range(0.0, 0.01) = 0.0008;
// Vertical resolution of the snapping grid (lower = chunkier wobble).
uniform float snap_resolution : hint_range(60.0, 720.0) = 200.0;
uniform float shade_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float color_levels : hint_range(4.0, 64.0) = 20.0;

uniform bool use_face = false;
uniform sampler2D face_eyes : source_color, filter_nearest, repeat_disable;
uniform sampler2D face_mouth : source_color, filter_nearest, repeat_disable;
uniform sampler2D face_extra : source_color, filter_nearest, repeat_disable;
// Local-space rectangle (centre, size) the face textures cover, seen from +Z.
uniform vec2 face_center = vec2(0.0, 0.0);
uniform vec2 face_size = vec2(0.4, 0.4);

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 world_normal;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(world_vertex.xz, cam_pos.xz);
	world_vertex.y -= dist * dist * curve_strength;

	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * world_vertex;
	vec2 grid = vec2(snap_resolution * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_resolution) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

vec3 layer(vec3 col, sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	return mix(col, c.rgb, c.a);
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint.rgb;

	if (use_face && obj_normal.z > 0.15) {
		vec2 fuv = vec2((obj_pos.x - face_center.x) / face_size.x + 0.5,
				0.5 - (obj_pos.y - face_center.y) / face_size.y);
		if (all(greaterThanEqual(fuv, vec2(0.0))) && all(lessThanEqual(fuv, vec2(1.0)))) {
			col = layer(col, face_eyes, fuv);
			col = layer(col, face_mouth, fuv);
			col = layer(col, face_extra, fuv);
		}
	}

	float ndl = dot(normalize(world_normal), normalize(light_dir)) * 0.5 + 0.5;
	col *= mix(1.0 - shade_strength, 1.0, ndl);

	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	col = floor(col * color_levels + 0.5 + threshold) / color_levels;
	ALBEDO = clamp(col, 0.0, 1.0);
}

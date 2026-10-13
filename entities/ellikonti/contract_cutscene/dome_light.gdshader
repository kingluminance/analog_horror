shader_type canvas_item;
// The dark inside Ellikonti (contract cutscene, step 6). Full-screen black
// (alpha = darkness) plus, while `sweep` runs 0 -> 1, a line of light passing
// over the inside of a round dome -- not a flat stripe: every pixel is turned
// into a view ray from the middle of a dome (camera tilted up a bit), and the
// light is a meridian of that dome, so it bends toward the zenith like a
// planetarium line. Faint latitude ribs light up only near the line so the
// dome's curve shows for a moment, then it is pitch black again.

uniform float darkness = 0.0;
uniform float sweep = -1.0;
uniform float fov_deg = 100.0;
uniform float pitch_deg = 28.0;
uniform float rib_step_deg = 12.0;

void fragment() {
	vec3 light = vec3(0.0);
	if (sweep >= 0.0 && sweep <= 1.0) {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * 2.0 * tan(radians(fov_deg) * 0.5);
		vec3 ray = normalize(vec3(p.x, -p.y, -1.0));
		float pc = cos(radians(pitch_deg));
		float ps = sin(radians(pitch_deg));
		ray = vec3(ray.x, ray.y * pc - ray.z * ps, ray.y * ps + ray.z * pc);

		float az = atan(ray.x, -ray.z);
		float el = asin(clamp(ray.y, -1.0, 1.0));
		float phi = mix(-1.7, 1.7, sweep);
		float d = abs(az - phi) * cos(el); // angular distance on the dome

		float core = exp(-pow(d / 0.012, 2.0));
		float glow = exp(-pow(d / 0.10, 2.0)) * 0.35;
		float step_rad = radians(rib_step_deg);
		float rib_d = abs(fract(el / step_rad + 0.5) - 0.5) * step_rad;
		float ribs = exp(-pow(rib_d / 0.004, 2.0)) * exp(-pow(d / 0.35, 2.0)) * 0.5;
		float dome_only = smoothstep(-0.12, 0.04, el); // no floor
		light = vec3(1.0) * clamp((core + glow + ribs) * dome_only, 0.0, 1.0);
	}
	COLOR = vec4(light, darkness);
}

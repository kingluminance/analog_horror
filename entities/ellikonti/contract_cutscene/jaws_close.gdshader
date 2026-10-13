shader_type canvas_item;
// The swallow (contract cutscene, end of step 5). Once the 3D mouth fills
// the screen this takes over in screen space so nothing behind the mouth can
// ever show: deep-red throat in the middle, and two big red half-circles --
// upper and lower jaw, round edges facing each other -- that clamp shut over
// it as `close` goes 0 -> 1 ("반원이 집어삼키면서 닫히는 느낌"). All reds,
// no black; the cut to black is the dome overlay drawn on top of this.

uniform float close = -1.0; // <0 hidden
uniform vec4 jaw_color : source_color = vec4(0.90, 0.06, 0.11, 1.0);
uniform vec4 lip_color : source_color = vec4(0.62, 0.0, 0.07, 1.0);
uniform vec4 throat_color : source_color = vec4(0.62, 0.02, 0.08, 1.0);
uniform float jaw_radius = 1.3; // in screen heights

void fragment() {
	if (close < 0.0) {
		COLOR = vec4(0.0);
	} else {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 p = (UV - 0.5) * vec2(aspect, 1.0); // y down, screen height = 1
		float k = clamp(close, 0.0, 1.0);
		k = k * k * (3.0 - 2.0 * k);
		// leading edge of the upper jaw: off the top edge -> well past centre, so
		// the two round edges overlap across the whole width when shut
		float edge = mix(-0.62, 0.26, k);
		vec2 upper_c = vec2(0.0, edge - jaw_radius);
		vec2 lower_c = vec2(0.0, -edge + jaw_radius);
		float du = jaw_radius - length(p - upper_c); // >0 inside the jaw
		float dl = jaw_radius - length(p - lower_c);
		float d = max(du, dl);

		// throat: matches the centre of the 3D mouth it replaces, a bit
		// deeper toward the middle
		vec3 col = mix(throat_color.rgb * 0.8, throat_color.rgb, smoothstep(0.0, 0.6, length(p)));
		if (d > 0.0) {
			// jaw: thick deeper-red lip right at the round edge, then the jaw
			float lip = 1.0 - smoothstep(0.0, 0.035, d);
			float shade = smoothstep(0.0, 0.5, d) * 0.15;
			col = mix(jaw_color.rgb * (1.0 - shade), lip_color.rgb, lip);
		}
		COLOR = vec4(col, 1.0);
	}
}

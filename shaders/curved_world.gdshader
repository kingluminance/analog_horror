shader_type spatial;

// World curves away from the camera — the core "wrongness" effect.
uniform float curve_strength : hint_range(0.0, 0.01) = 0.0008;
uniform vec4 albedo_color : source_color = vec4(1.0);

void vertex() {
	vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	float dist = distance(world_vertex.xz, cam_pos.xz);
	world_vertex.y -= dist * dist * curve_strength;
	VERTEX = (inverse(MODEL_MATRIX) * world_vertex).xyz;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
}

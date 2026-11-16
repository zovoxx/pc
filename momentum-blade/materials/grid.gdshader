// A clean grid pattern based on world position.
// The grid lines make speed easy to see when you move fast.
// Used for the arena floor and walls, each with its own colours
// (see the ShaderMaterials in scenes/arena.tscn).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.2, 0.22, 0.26, 1.0);
uniform vec4 line_color : source_color = vec4(0.32, 0.36, 0.44, 1.0);
// Size of one grid cell in meters.
uniform float cell_size = 2.0;
// Line thickness in pixels.
uniform float line_width = 1.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

// 1.0 on a grid line, 0.0 between lines (anti-aliased using screen-space width).
float grid_lines(vec2 cell, vec2 pixel_width) {
	vec2 dist = abs(fract(cell - 0.5) - 0.5) / pixel_width;
	return 1.0 - clamp(min(dist.x, dist.y) / line_width, 0.0, 1.0);
}

void fragment() {
	vec3 cell = world_pos / cell_size;
	vec3 pixel_width = max(fwidth(cell), vec3(0.00001));
	float line;
	// Pick the grid plane that matches the surface direction.
	if (world_normal.y > 0.5) {
		line = grid_lines(cell.xz, pixel_width.xz);
	} else if (world_normal.x > world_normal.z) {
		line = grid_lines(cell.zy, pixel_width.zy);
	} else {
		line = grid_lines(cell.xy, pixel_width.xy);
	}
	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	ROUGHNESS = roughness_value;
}

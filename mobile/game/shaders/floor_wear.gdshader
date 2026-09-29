shader_type canvas_item;
render_mode unshaded;

// World-space, non-tiled value noise: the two scales multiply the soft mask,
// so scaling/reusing the existing glow never exposes a repeated stamp.
uniform vec2 noise_scales;
uniform float noise_floor;
uniform vec2 noise_offset;
uniform vec4 floor_bounds;
uniform float soft_core;
varying vec2 world_at;

float hash_at(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_at(cell), hash_at(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_at(cell + vec2(0.0, 1.0)), hash_at(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_at + noise_offset;
	float mottle = mix(noise_floor, 1.0, field(p / noise_scales.x))
		* mix(noise_floor, 1.0, field(p / noise_scales.y));
	float inside = step(floor_bounds.x, world_at.x) * step(world_at.x, floor_bounds.z)
		* step(floor_bounds.y, world_at.y) * step(world_at.y, floor_bounds.w);
	// COLOR already includes the glow texture and modulate; apply only the mask.
	float radial = 1.0 - smoothstep(soft_core, 1.0, length(UV * 2.0 - 1.0));
	COLOR.a *= radial * mottle * inside;
}

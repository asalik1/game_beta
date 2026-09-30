shader_type canvas_item;

// The tile repeats horizontally. Its top and each doorway/span end need a
// soft transition into the dark wall; the bottom keeps its painted alpha.
uniform vec2 extent;
uniform vec2 feather;
varying vec2 local_at;

void vertex() {
	local_at = VERTEX;
}

void fragment() {
	float sides = smoothstep(0.0, feather.x, min(local_at.x, extent.x - local_at.x));
	float top = smoothstep(0.0, feather.y, local_at.y);
	COLOR.a *= sides * top;
}

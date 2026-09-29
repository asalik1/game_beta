shader_type canvas_item;
render_mode unshaded, blend_add;

// Light on the INSIDE of the lower-right silhouette, never an expanded outline.
// The body renders separately, retaining its own material and modulate effects.
uniform vec4 rim_color : source_color;
uniform float rim_strength : hint_range(0.0, 1.0);
// Framebuffer pixels: EnemyRim sends Balance.ENEMY_RIM_OFFSET_PX times the
// window's canvas stretch (1.5 canvas px is 2.25 here at 1080p, 3 at 1440p).
uniform float rim_offset_px : hint_range(0.5, 8.0);
uniform vec4 frame_uv_rect;

void fragment() {
	float center = texture(TEXTURE, UV).a;
	// Screen derivatives keep the light on the same side through flips, rotation,
	// sprite-sheet resolution changes and camera zoom.
	vec2 neighbor_uv = UV + (dFdx(UV) + dFdy(UV)) * rim_offset_px;
	vec2 inside = step(frame_uv_rect.xy, neighbor_uv)
		* step(neighbor_uv, frame_uv_rect.zw);
	float neighbor = texture(TEXTURE, neighbor_uv).a * inside.x * inside.y;
	float edge = max(center - neighbor, 0.0);
	// COLOR already contains the sampled texture. ONLY reuse its alpha, as in
	// silhouette.gdshader; multiplying RGB would darken the very edge we light.
	COLOR = vec4(rim_color.rgb, edge * rim_color.a * rim_strength * COLOR.a);
}

shader_type canvas_item;

// An outline-only copy of the hero, drawn above opaque architecture while the
// actual hero remains correctly hidden behind it. The sprite sheet's own alpha
// supplies the silhouette; the interior stays fully transparent.
uniform vec4 outline_color : source_color = vec4(0.78, 0.94, 1.0, 0.60);
uniform float outline_width : hint_range(0.5, 5.0, 0.05) = 3.25;

void fragment() {
	float center = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
	float a0 = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float a1 = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float a2 = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float a3 = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float a4 = texture(TEXTURE, UV + px).a;
	float a5 = texture(TEXTURE, UV - px).a;
	float a6 = texture(TEXTURE, UV + vec2(px.x, -px.y)).a;
	float a7 = texture(TEXTURE, UV + vec2(-px.x, px.y)).a;
	float around = max(max(max(a0, a1), max(a2, a3)),
		max(max(a4, a5), max(a6, a7)));
	float around_min = min(min(min(a0, a1), min(a2, a3)),
		min(min(a4, a5), min(a6, a7)));
	float outer_edge = max(around - center, 0.0);
	float inner_edge = center * (1.0 - around_min);
	float edge = max(outer_edge, inner_edge);
	COLOR = vec4(outline_color.rgb, edge * outline_color.a * COLOR.a);
}

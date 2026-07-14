shader_type canvas_item;

// A luminance-shaded solid tint: fills the sprite's opaque shape with `tint`,
// brighter where the source is brighter (so it keeps its form), which lets a
// LIGHT colour like gold actually READ. A plain modulate multiply can only
// darken a textured sprite, so bright tints wash out. Used for coloured
// after-images (Golden Ronin's gold dash / ult echoes). Alpha rides the node's
// modulate.a, so a fade tween on modulate:a still fades the ghost.
uniform vec3 tint = vec3(1.0, 0.82, 0.35);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(tint * (0.5 + 0.65 * lum), t.a * COLOR.a);
}

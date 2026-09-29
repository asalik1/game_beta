shader_type canvas_item;

// The rim is a separate additive child (enemy_rim.gd), not a body material.
// Keep this pass on the body: its tint and lighting still own combat/status
// colour, while a bounded brightness gain preserves the painted form.
uniform float hit_strength : hint_range(0.0, 1.0) = 0.0;
varying vec4 body_tint;

void vertex() {
	body_tint = COLOR; // Capture modulation BEFORE the fragment texture sample.
}

void fragment() {
	vec3 painted = texture(TEXTURE, UV).rgb;
	// A plain gain keeps every painted hue and value step: lifting channels
	// toward luminance (the first cut) turned orange lava pink at the peak
	// (shot.bat hit_highlight). Bright details pass the glow threshold and pop.
	// Tint is applied AFTER, so yellow/blue/red tells keep their hue at the peak.
	vec3 result = painted * (1.0 + hit_strength);
	// Fragment COLOR already includes the texture: reuse ONLY its alpha.
	COLOR = vec4(result * body_tint.rgb, COLOR.a);
}

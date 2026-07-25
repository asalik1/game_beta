shader_type canvas_item;

// Phantom spectral charge (owner-designed, 2026-07-24): sustained motion
// brightens him, standing still settles him darker. `charge` is driven
// per-frame by the Phantom's SkinAmbient (player_combat.gd): 0 = settled,
// 1 = fully charged.
//
// Owner's model: an EXPOSURE/BRIGHTNESS dial (like editing an iPhone photo)
// — NOT a mix toward white. Brightening lifts the sprite's OWN colors
// (gamma shadow/midtone lift + gain), so hues stay saturated instead of
// washing into white paint. Earlier white-mix versions read as "layers of
// white thrown on" and were rejected.
//
// TRAP (bit v1): fragment COLOR arrives premultiplied (modulate x TEXTURE);
// reuse ONLY COLOR.a (silhouette.gdshader convention), never `* COLOR`.
uniform float charge : hint_range(0.0, 1.0) = 0.0;
// Darkening at full rest. Owner-set: 40%.
uniform float dark_dip : hint_range(0.0, 1.0) = 0.40;
// Full-charge exposure: gamma (lower = stronger shadow/midtone lift) and
// gain (overall exposure multiplier).
uniform float bright_gamma : hint_range(0.2, 1.0) = 0.55;
uniform float bright_gain : hint_range(1.0, 3.0) = 1.35;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = pow(t.rgb, vec3(mix(1.0, bright_gamma, charge)));
	c *= mix(1.0 - dark_dip, bright_gain, charge);
	COLOR = vec4(min(c, vec3(1.0)), t.a * COLOR.a);
}

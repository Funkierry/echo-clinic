shader_type canvas_item;
// v0.8 screen pass: soft bloom on bright text, scanlines, vignette, and an RGB split driven by `glitch`.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float bloom = 0.55;
uniform float scan = 0.055;
uniform float time = 0.0;

vec3 bright(vec2 uv) {
	vec3 c = texture(screen, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(0.42, 0.95, l);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// Glitch: a few horizontal bands slide sideways.
	float band = step(0.82, fract(sin(floor(uv.y * 38.0 + time * 9.0) * 91.7) * 4375.5));
	uv.x += band * glitch * 0.012 * sin(time * 47.0);
	float split = 0.5 + glitch * 4.0;
	vec3 col;
	col.r = texture(screen, uv + vec2(px.x * split, 0.0)).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - vec2(px.x * split, 0.0)).b;
	// Two-ring bloom from 12 taps; cheap enough for the Compatibility renderer.
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		vec2 d = vec2(cos(a), sin(a));
		glow += bright(uv + d * px * 3.0);
		glow += bright(uv + d * px * 7.5) * 0.7;
	}
	col += glow / 10.2 * bloom;
	float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	col *= 1.0 - scan * line;
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * 0.55;
	COLOR = vec4(col, 1.0);
}

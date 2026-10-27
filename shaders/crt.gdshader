shader_type canvas_item;
render_mode unshaded;
// Old-monitor look, applied over the whole frame (world + HUD + menus):
// barrel curvature with rounded bezel corners, edge chromatic aberration,
// soft phosphor glow, scanlines locked to a ~216-line "virtual" screen,
// an aperture-grille mask, faint flicker/noise and a corner vignette.
// `strength` scales everything so it can be dialled down in settings.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float curvature : hint_range(0.0, 0.2) = 0.045;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.04;
uniform float scanline_lines = 216.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.24;
uniform float mask_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float aberration_px = 1.6;
uniform float glow : hint_range(0.0, 1.0) = 0.22;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.022;

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + dot(c, c) * curvature * strength;
	// Shrink slightly so the curved edges stay on screen.
	c /= 1.0 + curvature * strength * 1.4;
	return c * 0.5 + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = barrel(SCREEN_UV);

	// Rounded bezel: signed distance to a rounded rectangle.
	vec2 q = abs(uv - 0.5) - (0.5 - corner_radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float inside = 1.0 - smoothstep(-px.y * 2.0, 0.0, d);

	// RGB split that grows towards the edges.
	vec2 from_center = uv - 0.5;
	vec2 split = from_center * 2.0 * aberration_px * px * strength;
	vec3 col;
	col.r = texture(screen_tex, uv + split).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - split).b;

	// Phosphor bleed: a blurred copy from the mip chain.
	vec3 bleed = textureLod(screen_tex, uv, 3.0).rgb;
	col += bleed * glow * strength;

	// Scanlines in curved space so they bend with the glass.
	float line = 0.5 + 0.5 * cos(uv.y * scanline_lines * TAU);
	// Bright pixels bloom across the dark gap like a real beam.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float depth = scanline_intensity * (1.0 - clamp(luma, 0.0, 1.0) * 0.5);
	col *= 1.0 - depth * (1.0 - line) * strength;

	// Aperture grille: R, G, B stripes three screen pixels wide.
	float stripe = mod(floor(FRAGCOORD.x), 3.0);
	vec3 mask = vec3(stripe == 0.0 ? 1.0 : 1.0 - mask_intensity,
		stripe == 1.0 ? 1.0 : 1.0 - mask_intensity,
		stripe == 2.0 ? 1.0 : 1.0 - mask_intensity);
	col *= mix(vec3(1.0), mask, strength);

	// Make up the brightness the lines and mask took away.
	col *= 1.0 + (scanline_intensity * 0.5 + mask_intensity * 0.6) * strength;

	col *= 1.0 - flicker * strength * (0.5 + 0.5 * sin(TIME * 120.0));
	col += (hash(uv * 800.0 + fract(TIME * 7.0)) - 0.5) * noise_amount * strength;

	float vig = 1.0 - dot(from_center, from_center) * vignette * 2.2 * strength;
	col *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(col * inside, 1.0);
}

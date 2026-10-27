shader_type canvas_item;
// Pixel-art iris wipe: a circle closes on the centre in chunky blocks with
// an ordered (Bayer) dither band at its edge. progress 0 = open, 1 = black.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float block = 8.0;
uniform vec4 color : source_color = vec4(0.051, 0.055, 0.086, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / block);
	vec2 centre = (cell * block + block * 0.5) - screen * 0.5;
	float d = length(centre) / length(screen * 0.5);
	float radius = (1.0 - progress) * 1.25;
	float band = 0.18;
	float t = clamp((d - (radius - band)) / band, 0.0, 1.0);
	float on = t > bayer4(cell) ? 1.0 : 0.0;
	COLOR = vec4(color.rgb, color.a * on);
}

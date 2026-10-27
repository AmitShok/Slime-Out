shader_type canvas_item;
// Full-screen overlay: soft vignette, red hurt flash and a low-health pulse.

uniform float vignette : hint_range(0.0, 1.0) = 0.38;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float low_health : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float edge = length(uv * vec2(1.5, 1.0));
	float dark = smoothstep(0.42, 1.0, edge) * vignette;
	float pulse = low_health * (0.55 + 0.45 * sin(TIME * 6.0));
	float red = clamp(damage + pulse * 0.6, 0.0, 1.0) * smoothstep(0.2, 0.9, edge) * 0.75;
	float alpha = clamp(dark + red, 0.0, 0.92);
	vec3 color = (vec3(0.02, 0.02, 0.05) * dark + vec3(0.7, 0.05, 0.12) * red) / max(dark + red, 0.0001);
	COLOR = vec4(color, alpha);
}

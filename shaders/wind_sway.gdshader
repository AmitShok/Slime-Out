shader_type canvas_item;
// Foliage sway: shears the top of a base-anchored sprite (origin at its
// feet) in whole-pixel steps. Phase comes from world position so
// neighbouring plants don't move in lockstep.

uniform float height = 32.0;
uniform float strength = 1.0;
uniform float speed = 1.4;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float weight = clamp(-VERTEX.y / height, 0.0, 1.0);
	float wave = sin(TIME * speed + world.x * 0.045 + world.y * 0.03)
		+ 0.5 * sin(TIME * speed * 2.3 + world.x * 0.11);
	VERTEX.x += floor(wave * strength * weight + 0.5);
}

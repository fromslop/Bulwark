// Grain: a light, flickering film grain over the whole game (items, hand, attacks) so the
// play field sits in the same world as the thermal-graded room, without touching colours.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float grain = 0.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / 2.0);
	c += (hash(cell + floor(TIME * 12.0)) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}

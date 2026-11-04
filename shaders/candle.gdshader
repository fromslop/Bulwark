// Candle: you carry the only light. Everything is dark except a flickering pool around
// your hand. The attack zone, fire, charge and gold still glow on their own, so you
// can read danger in the dark but have to bring the light to see your gear.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 hand_uv = vec2(0.5, 0.8);
uniform float radius = 0.28;
uniform vec2 lamp_uv = vec2(-10.0, -10.0);  // a lantern in the play field, if there is one
uniform float lamp_radius = 0.22;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = (SCREEN_UV - hand_uv) * vec2(16.0 / 9.0, 1.0);
	float flick = 1.0 + (hash(floor(TIME * 14.0)) - 0.5) * 0.08;
	float light = smoothstep(radius * flick, radius * 0.25, length(d));
	vec2 dl = (SCREEN_UV - lamp_uv) * vec2(16.0 / 9.0, 1.0);
	light = max(light, smoothstep(lamp_radius * flick, lamp_radius * 0.25, length(dl)));
	light += 0.05;  // the faintest outline of the room
	float sat = max(src.r, max(src.g, src.b)) - min(src.r, min(src.g, src.b));
	float glow = smoothstep(0.35, 0.7, sat) * smoothstep(0.3, 0.6, max(src.r, max(src.g, src.b)));
	vec3 warm = src * vec3(1.0, 0.85, 0.6);
	vec3 c = warm * light + src * glow * (1.0 - light) * 0.9;
	COLOR = vec4(c, 1.0);
}

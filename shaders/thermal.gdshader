// World grade: the 3D room and enemy are re-coloured through a five-stop gradient by how
// "hot" (bright and warm) each pixel is, with chunky pixels and a flickering grain. Each
// setting supplies its own gradient and texture, so every place has its own palette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel = 2.0;
uniform float noise = 0.04;
uniform float gamma = 0.75;     // < 1 lifts the darks, > 1 crushes them
uniform float contrast = 1.0;
uniform float keep = 0.0;       // how much of the scene's own colour survives the grade (0 = none): lets the characters' palettes show
uniform vec3 c0 = vec3(0.0, 0.0, 0.05);
uniform vec3 c1 = vec3(0.2, 0.0, 0.5);
uniform vec3 c2 = vec3(0.85, 0.1, 0.3);
uniform vec3 c3 = vec3(1.0, 0.6, 0.0);
uniform vec3 c4 = vec3(1.0, 1.0, 0.85);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 grade(float t) {
	if (t < 0.25) return mix(c0, c1, t / 0.25);
	if (t < 0.5) return mix(c1, c2, (t - 0.25) / 0.25);
	if (t < 0.75) return mix(c2, c3, (t - 0.5) / 0.25);
	return mix(c3, c4, (t - 0.75) / 0.25);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * res / pixel);
	vec2 uv = (cell + 0.5) * pixel / res;
	vec3 src = texture(screen_tex, uv).rgb;
	float t = dot(src, vec3(0.6, 0.3, 0.1)) + max(src.r - src.b, 0.0) * 0.35;
	t = pow(max(t, 0.0), gamma);
	t = (t - 0.5) * contrast + 0.5;
	t = clamp(t + (hash(cell + floor(TIME * 12.0)) - 0.5) * noise, 0.0, 1.0);
	COLOR = vec4(mix(grade(t), src, keep), 1.0);
}

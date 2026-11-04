shader_type canvas_item;
// The shop gong's polished face, showing what waits beyond it: a live view of the next
// arena and its foe (scrying.gd renders it), mirrored, bulged like a convex mirror,
// rippling like struck metal, graded through the next setting's own five colours, and
// washed in bronze. Faint until the hand comes close.

uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform float reveal = 0.18;  // how clearly it shows (the hand leaning in)
uniform float shimmer = 0.0;  // 1: something secret waits (a slow gold sweep)
uniform float ripple = 0.0;  // extra ripple just after a strike

vec3 ramp(float x) {
	x = clamp(x, 0.0, 1.0) * 4.0;
	if (x < 1.0) return mix(c0.rgb, c1.rgb, x);
	if (x < 2.0) return mix(c1.rgb, c2.rgb, x - 1.0);
	if (x < 3.0) return mix(c2.rgb, c3.rgb, x - 2.0);
	return mix(c3.rgb, c4.rgb, x - 3.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	if (r > 1.0) discard;
	// a reflection: mirrored, bulged toward the middle like a convex mirror
	vec2 q = vec2(-p.x, p.y);
	q *= 0.78 + 0.22 * r * r;
	// the metal never sits quite still
	float wob = 0.006 + 0.02 * ripple;
	q += wob * vec2(sin(q.y * 26.0 + TIME * 1.9), cos(q.x * 22.0 + TIME * 1.6));
	vec3 seen = texture(TEXTURE, q + 0.5).rgb;
	float lum = dot(seen, vec3(0.3, 0.59, 0.11));
	vec3 graded = ramp(pow(lum, 0.85));
	vec3 bronze = vec3(0.86, 0.62, 0.3);
	// the place's own colours, tinted toward the bronze they're seen in (never added on top:
	// bright places stay readable)
	vec3 col = graded * mix(vec3(1.0), bronze * 1.15, 0.4) * 0.85 + bronze * 0.06;
	// a gold sweep when the way beyond is a secret one
	float sweep = smoothstep(0.08, 0.0, abs(fract(TIME * 0.25 + p.x * 0.6 - p.y * 0.4) - 0.5) - 0.38);
	col += vec3(1.0, 0.82, 0.35) * sweep * shimmer * 0.45;
	// polished highlight across the top left, darker toward the rim
	col += vec3(1.0, 0.9, 0.7) * smoothstep(0.55, 0.0, length(p - vec2(-0.18, -0.2))) * 0.12;
	float rim = smoothstep(1.0, 0.82, r);
	COLOR = vec4(col, reveal * rim);
}

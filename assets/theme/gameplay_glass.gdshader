shader_type canvas_item;

uniform bool seafoam = false;

float glow(vec2 point, vec2 center, vec2 stretch) {
	vec2 delta = (point - center) * stretch;
	return exp(-dot(delta, delta));
}

vec3 bubble(vec3 color, vec2 point, vec2 center, float radius) {
	vec2 p = (point - center) / radius;
	float d = length(p);
	float inside = 1.0 - smoothstep(0.97, 1.04, d);
	float rim = smoothstep(0.76, 1.0, d) * inside;
	float sheen = glow(p, vec2(-0.42, -0.53), vec2(5.5, 8.0));
	float reflection = glow(p, vec2(0.55, 0.49), vec2(7.0, 5.0));
	color = mix(color, vec3(0.76, 0.54, 1.0), inside * d * 0.18);
	return mix(color, vec3(1.0, 0.96, 1.0), clamp(rim * 0.85 + (sheen + reflection) * inside, 0.0, 1.0));
}

vec3 sparkle(vec3 color, vec2 p, vec2 center, float scale) {
	vec2 delta = abs(p - center) / scale;
	float rays = exp(-delta.x * 3.0 - delta.y * 34.0) + exp(-delta.x * 34.0 - delta.y * 3.0);
	return mix(color, vec3(1.0, 0.97, 0.80), clamp(rays + exp(-length(delta) * 4.0) * 0.5, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x, uv.y * 2.1);
	vec3 color = mix(vec3(0.78, 0.67, 0.96), vec3(0.90, 0.81, 0.99), uv.y);
	color = mix(color, vec3(0.98, 0.94, 1.0), glow(uv, vec2(0.48, 0.05), vec2(1.8, 4.2)));
	color = mix(color, vec3(0.75, 0.77, 1.0), glow(uv, vec2(0.54, 0.58), vec2(2.2, 4.0)));
	float wave = 0.965 + 0.035 * sin(uv.x * 6.2 + 0.1);
	color = mix(color, mix(vec3(0.59, 0.39, 0.89), vec3(0.79, 0.62, 0.98), uv.x), smoothstep(wave, wave + 0.003, uv.y));
	color = mix(color, vec3(1.0, 0.87, 0.66), (1.0 - smoothstep(0.0, 0.003, abs(uv.y - wave))) * 0.82);
	color = bubble(color, p, vec2(0.055, 0.58), 0.035);
	color = bubble(color, p, vec2(0.94, 0.30), 0.025);
	color = bubble(color, p, vec2(0.945, 0.97), 0.039);
	color = bubble(color, p, vec2(0.075, 1.25), 0.030);
	color = bubble(color, p, vec2(0.91, 1.60), 0.043);
	color = sparkle(color, p, vec2(0.082, 0.10), 0.067);
	color = sparkle(color, p, vec2(0.105, 0.92), 0.068);
	color = sparkle(color, p, vec2(0.88, 1.19), 0.063);
	if (seafoam) {
		color = mix(color, vec3(color.r * 0.85, min(1.0, color.g + 0.18), color.b * 0.94), 0.82);
	}
	COLOR *= vec4(color, 1.0);
}

shader_type canvas_item;

void fragment() {
	vec2 p = UV;
	float glow = 1.0 - smoothstep(0.0, 0.76, distance(p * vec2(1.0, 0.8), vec2(0.46, 0.29)));
	vec3 violet = mix(vec3(0.42, 0.24, 0.78), vec3(0.68, 0.48, 0.95), p.y);
	vec3 color = mix(violet, vec3(0.93, 0.78, 1.0), glow * 0.86);
	float hill = 0.87 + 0.05 * sin(p.x * 6.4 + 0.9);
	color = mix(color, vec3(0.53, 0.32, 0.89), smoothstep(hill, hill + 0.16, p.y) * 0.64);
	COLOR = vec4(color, 1.0);
}

shader_type canvas_item;

uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform vec4 region;
uniform vec2 control_size;
uniform bool hero = false;

void fragment() {
	float scale = min(control_size.x / (region.z * (hero ? 0.67 : 1.0)), control_size.y / region.w);
	vec2 position = region.xy + region.zw * 0.5 + (UV - vec2(0.5)) * control_size / max(scale, 0.001);
	vec2 image_size = vec2(textureSize(artwork, 0));
	vec4 image = texture(artwork, position / image_size);
	vec2 edge = min(position - region.xy, region.xy + region.zw - position);
	float fade = smoothstep(0.0, hero ? 32.0 : 14.0, min(edge.x, edge.y));
	if (hero) {
		float central = 1.0 - smoothstep(85.0, 135.0, abs(position.x - 512.0));
		fade *= max(central, smoothstep(104.0, 143.0, position.y));
		fade *= smoothstep(0.0, 0.06, min(UV.x, 1.0 - UV.x));
	}
	COLOR = vec4(image.rgb, image.a * fade);
}

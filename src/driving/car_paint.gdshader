shader_type canvas_item;
// Repaints light, unsaturated body paint; lamps, glass, stripes, tyres, and plates keep
// their colors because they are saturated or dark.

uniform vec4 paint : source_color = vec4(1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float high = max(source.r, max(source.g, source.b));
	float low = min(source.r, min(source.g, source.b));
	float saturation = high > 0.0 ? (high - low) / high : 0.0;
	float weight = (1.0 - smoothstep(0.10, 0.22, saturation)) * smoothstep(0.42, 0.55, high);
	float shade = clamp((high - 0.42) / 0.58, 0.0, 1.0);
	vec3 painted = paint.rgb * mix(0.5, 1.08, shade) + vec3(pow(shade, 6.0) * 0.16);
	COLOR.rgb = mix(COLOR.rgb, clamp(painted, 0.0, 1.0), weight);
}
